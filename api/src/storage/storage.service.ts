import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';
import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

// MinIO is S3-compatible, so we drive it with the AWS SDK v3 S3 client.
// Uploads go straight from the client to MinIO via a presigned PUT URL;
// the API never proxies file bytes.
@Injectable()
export class StorageService {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly publicBaseUrl: string;

  constructor(config: ConfigService) {
    const useSsl = config.get<string>('MINIO_USE_SSL') === 'true';
    const scheme = useSsl ? 'https' : 'http';
    const host = config.get<string>('MINIO_ENDPOINT') ?? 'localhost';
    const port = config.get<string>('MINIO_PORT') ?? '9000';
    const endpoint = `${scheme}://${host}:${port}`;

    this.bucket = config.get<string>('MINIO_BUCKET') ?? 'product-images';
    // Public (browser-reachable) base may differ from the internal endpoint
    // (e.g. an Android emulator must use 10.0.2.2 instead of localhost).
    this.publicBaseUrl = config.get<string>('MINIO_PUBLIC_URL') ?? endpoint;

    this.client = new S3Client({
      endpoint,
      region: config.get<string>('MINIO_REGION') ?? 'us-east-1',
      forcePathStyle: true, // MinIO requires path-style addressing
      credentials: {
        accessKeyId: config.getOrThrow<string>('MINIO_ROOT_USER'),
        secretAccessKey: config.getOrThrow<string>('MINIO_ROOT_PASSWORD'),
      },
    });
  }

  buildKey(productId: string, ext: string): string {
    return `products/${productId}/${randomUUID()}.${ext}`;
  }

  createPresignedUpload(
    key: string,
    contentType: string,
    expiresIn = 900,
  ): Promise<string> {
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: contentType,
    });
    return getSignedUrl(this.client, command, { expiresIn });
  }

  async deleteObject(key: string): Promise<void> {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: key }),
    );
  }

  publicUrl(key: string): string {
    return `${this.publicBaseUrl}/${this.bucket}/${key}`;
  }

  // Extract the object key back out of a stored public URL, host-agnostic.
  keyFromUrl(url: string): string {
    const path = new URL(url).pathname.replace(/^\/+/, '');
    const prefix = `${this.bucket}/`;
    return path.startsWith(prefix) ? path.slice(prefix.length) : path;
  }
}
