import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Address, Prisma } from '../generated/prisma/client';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

// Invariant kept by every mutation here: while a user has any addresses,
// exactly one of them is the default.
@Injectable()
export class AddressService {
  constructor(private readonly prisma: PrismaService) {}

  list(userId: string) {
    return this.prisma.address.findMany({
      where: { userId },
      orderBy: [{ isDefault: 'desc' }, { id: 'asc' }],
    });
  }

  // The first address becomes the default automatically; later ones only on
  // request, in which case the flag moves off the previous default.
  async create(userId: string, dto: CreateAddressDto) {
    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.address.count({ where: { userId } });
      const isDefault = existing === 0 || (dto.isDefault ?? false);
      if (isDefault && existing > 0) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      return tx.address.create({
        data: {
          userId,
          fullName: dto.fullName,
          phone: dto.phone,
          line1: dto.line1,
          line2: dto.line2 ?? null,
          city: dto.city,
          district: dto.district,
          postalCode: dto.postalCode,
          country: dto.country ?? 'TR',
          isDefault,
        },
      });
    });
  }

  async update(userId: string, id: string, dto: UpdateAddressDto) {
    const address = await this.ensureOwned(userId, id);

    // The default flag moves between addresses; it never just disappears.
    if (dto.isDefault === false && address.isDefault) {
      throw new BadRequestException(
        'Set another address as the default first',
      );
    }

    const data: Prisma.AddressUpdateInput = {};
    if (dto.fullName !== undefined) data.fullName = dto.fullName;
    if (dto.phone !== undefined) data.phone = dto.phone;
    if (dto.line1 !== undefined) data.line1 = dto.line1;
    if (dto.line2 !== undefined) data.line2 = dto.line2;
    if (dto.city !== undefined) data.city = dto.city;
    if (dto.district !== undefined) data.district = dto.district;
    if (dto.postalCode !== undefined) data.postalCode = dto.postalCode;
    if (dto.country !== undefined) data.country = dto.country;
    if (dto.isDefault !== undefined) data.isDefault = dto.isDefault;

    return this.prisma.$transaction(async (tx) => {
      if (dto.isDefault === true && !address.isDefault) {
        await tx.address.updateMany({
          where: { userId, isDefault: true },
          data: { isDefault: false },
        });
      }
      return tx.address.update({ where: { id }, data });
    });
  }

  // Orders keep a live reference to their delivery address; deleting one
  // that has been used would hollow out that history, so block it.
  async remove(userId: string, id: string): Promise<void> {
    const address = await this.ensureOwned(userId, id);
    const orders = await this.prisma.order.count({ where: { addressId: id } });
    if (orders > 0) {
      throw new ConflictException(
        'Cannot delete an address already used by orders',
      );
    }
    await this.prisma.$transaction(async (tx) => {
      await tx.address.delete({ where: { id } });
      // Removing the default promotes the oldest remaining address.
      if (address.isDefault) {
        const next = await tx.address.findFirst({
          where: { userId },
          orderBy: { id: 'asc' },
        });
        if (next) {
          await tx.address.update({
            where: { id: next.id },
            data: { isDefault: true },
          });
        }
      }
    });
  }

  private async ensureOwned(userId: string, id: string): Promise<Address> {
    const address = await this.prisma.address.findFirst({
      where: { id, userId },
    });
    if (!address) {
      throw new NotFoundException('Address not found');
    }
    return address;
  }
}
