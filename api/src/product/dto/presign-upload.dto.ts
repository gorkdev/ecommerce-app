import { IsIn } from 'class-validator';

// Allowed image content types and their file extensions.
export const ALLOWED_IMAGE_TYPES: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

export class PresignUploadDto {
  @IsIn(Object.keys(ALLOWED_IMAGE_TYPES))
  contentType: string;
}
