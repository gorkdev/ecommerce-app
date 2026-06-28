import { IsInt, IsOptional, IsString, Min, MinLength } from 'class-validator';

export class AttachImageDto {
  // Object key returned by the presign step (already uploaded to MinIO).
  @IsString()
  @MinLength(1)
  key: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;
}
