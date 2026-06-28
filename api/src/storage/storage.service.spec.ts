import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { StorageService } from './storage.service';

const sendMock = jest.fn();

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(),
}));

jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: jest.fn().mockImplementation(() => ({ send: sendMock })),
  PutObjectCommand: jest.fn((input: unknown) => ({ kind: 'put', input })),
  DeleteObjectCommand: jest.fn((input: unknown) => ({ kind: 'delete', input })),
}));

const CONFIG: Record<string, string | undefined> = {
  MINIO_USE_SSL: 'false',
  MINIO_ENDPOINT: 'localhost',
  MINIO_PORT: '9000',
  MINIO_BUCKET: 'product-images',
  MINIO_REGION: 'us-east-1',
};

const configService = {
  get: (key: string) => CONFIG[key],
  getOrThrow: (key: string) =>
    ({ MINIO_ROOT_USER: 'minioadmin', MINIO_ROOT_PASSWORD: 'minioadmin' })[key],
} as never;

describe('StorageService', () => {
  let service: StorageService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new StorageService(configService);
  });

  it('builds a namespaced object key', () => {
    const key = service.buildKey('p1', 'png');
    expect(key).toMatch(/^products\/p1\/[0-9a-f-]{36}\.png$/);
  });

  it('builds a public URL from base + bucket + key', () => {
    expect(service.publicUrl('products/p1/x.png')).toBe(
      'http://localhost:9000/product-images/products/p1/x.png',
    );
  });

  it('extracts the key from a public URL regardless of host', () => {
    expect(
      service.keyFromUrl(
        'http://10.0.2.2:9000/product-images/products/p1/x.png',
      ),
    ).toBe('products/p1/x.png');
  });

  it('returns a presigned upload URL', async () => {
    (getSignedUrl as jest.Mock).mockResolvedValue('http://signed-url');

    const url = await service.createPresignedUpload(
      'products/p1/x.png',
      'image/png',
    );

    expect(url).toBe('http://signed-url');
    expect(getSignedUrl).toHaveBeenCalledTimes(1);
  });

  it('sends a delete command', async () => {
    await service.deleteObject('products/p1/x.png');
    expect(sendMock).toHaveBeenCalledWith(
      expect.objectContaining({ kind: 'delete' }),
    );
  });
});
