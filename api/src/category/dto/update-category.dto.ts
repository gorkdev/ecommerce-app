import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateCategoryDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  slug?: string;

  @IsOptional()
  @IsString()
  parentId?: string;
}
