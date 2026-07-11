import { Test } from '@nestjs/testing';
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { AddressService } from './address.service';
import { PrismaService } from '../prisma/prisma.service';

type PrismaMock = {
  address: {
    findMany: jest.Mock;
    findFirst: jest.Mock;
    count: jest.Mock;
    create: jest.Mock;
    update: jest.Mock;
    updateMany: jest.Mock;
    delete: jest.Mock;
  };
  order: { count: jest.Mock };
  $transaction: jest.Mock;
};

const address = (over: Partial<Record<string, unknown>> = {}) => ({
  id: 'a1',
  userId: 'u1',
  fullName: 'Ada Lovelace',
  phone: '+905551112233',
  line1: 'Analytical Engine St. 42',
  line2: null,
  city: 'Istanbul',
  district: 'Kadikoy',
  postalCode: '34710',
  country: 'TR',
  isDefault: true,
  ...over,
});

describe('AddressService', () => {
  let service: AddressService;
  let prisma: PrismaMock;

  beforeEach(async () => {
    prisma = {
      address: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn(),
        count: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        delete: jest.fn(),
      },
      order: { count: jest.fn().mockResolvedValue(0) },
      $transaction: jest.fn((arg: unknown) =>
        Array.isArray(arg)
          ? Promise.all(arg as Promise<unknown>[])
          : (arg as (tx: PrismaMock) => unknown)(prisma),
      ),
    };

    const moduleRef = await Test.createTestingModule({
      providers: [AddressService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = moduleRef.get(AddressService);
  });

  describe('create', () => {
    it('forces the first address to be the default', async () => {
      prisma.address.count.mockResolvedValue(0);
      prisma.address.create.mockResolvedValue(address());

      await service.create('u1', {
        fullName: 'Ada Lovelace',
        phone: '+905551112233',
        line1: 'Analytical Engine St. 42',
        city: 'Istanbul',
        district: 'Kadikoy',
        postalCode: '34710',
        isDefault: false, // Ignored: the only address must be the default.
      });

      expect(prisma.address.updateMany).not.toHaveBeenCalled();
      expect(prisma.address.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ isDefault: true, country: 'TR' }),
        }),
      );
    });

    it('moves the default flag when a later address claims it', async () => {
      prisma.address.count.mockResolvedValue(1);
      prisma.address.create.mockResolvedValue(address({ id: 'a2' }));

      await service.create('u1', {
        fullName: 'Ada Lovelace',
        phone: '+905551112233',
        line1: 'Second Home 7',
        city: 'Ankara',
        district: 'Cankaya',
        postalCode: '06690',
        isDefault: true,
      });

      expect(prisma.address.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1', isDefault: true },
        data: { isDefault: false },
      });
    });

    it('leaves the existing default alone for a plain new address', async () => {
      prisma.address.count.mockResolvedValue(1);
      prisma.address.create.mockResolvedValue(address({ id: 'a2' }));

      await service.create('u1', {
        fullName: 'Ada Lovelace',
        phone: '+905551112233',
        line1: 'Second Home 7',
        city: 'Ankara',
        district: 'Cankaya',
        postalCode: '06690',
      });

      expect(prisma.address.updateMany).not.toHaveBeenCalled();
      expect(prisma.address.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ isDefault: false }),
        }),
      );
    });
  });

  describe('update', () => {
    it('rejects an address the caller does not own', async () => {
      prisma.address.findFirst.mockResolvedValue(null);

      await expect(
        service.update('u1', 'foreign', { city: 'Izmir' }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });

    it('refuses to strip the default flag directly', async () => {
      prisma.address.findFirst.mockResolvedValue(address({ isDefault: true }));

      await expect(
        service.update('u1', 'a1', { isDefault: false }),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(prisma.address.update).not.toHaveBeenCalled();
    });

    it('unsets the previous default when another one takes over', async () => {
      prisma.address.findFirst.mockResolvedValue(
        address({ id: 'a2', isDefault: false }),
      );
      prisma.address.update.mockResolvedValue(address({ id: 'a2' }));

      await service.update('u1', 'a2', { isDefault: true });

      expect(prisma.address.updateMany).toHaveBeenCalledWith({
        where: { userId: 'u1', isDefault: true },
        data: { isDefault: false },
      });
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a2' },
        data: { isDefault: true },
      });
    });

    it('patches only the provided fields', async () => {
      prisma.address.findFirst.mockResolvedValue(address());
      prisma.address.update.mockResolvedValue(address({ city: 'Izmir' }));

      await service.update('u1', 'a1', { city: 'Izmir' });

      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a1' },
        data: { city: 'Izmir' },
      });
    });
  });

  describe('remove', () => {
    it('blocks deleting an address referenced by orders', async () => {
      prisma.address.findFirst.mockResolvedValue(address());
      prisma.order.count.mockResolvedValue(2);

      await expect(service.remove('u1', 'a1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(prisma.address.delete).not.toHaveBeenCalled();
    });

    it('promotes the oldest remaining address when the default goes', async () => {
      prisma.address.findFirst
        .mockResolvedValueOnce(address({ isDefault: true })) // ensureOwned
        .mockResolvedValueOnce(address({ id: 'a2', isDefault: false })); // next
      prisma.address.delete.mockResolvedValue({});

      await service.remove('u1', 'a1');

      expect(prisma.address.delete).toHaveBeenCalledWith({
        where: { id: 'a1' },
      });
      expect(prisma.address.update).toHaveBeenCalledWith({
        where: { id: 'a2' },
        data: { isDefault: true },
      });
    });

    it('deletes a non-default address without touching the others', async () => {
      prisma.address.findFirst.mockResolvedValue(
        address({ id: 'a2', isDefault: false }),
      );
      prisma.address.delete.mockResolvedValue({});

      await service.remove('u1', 'a2');

      expect(prisma.address.update).not.toHaveBeenCalled();
    });
  });
});
