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

  // `null` detaches the category to the top level; `@IsOptional` also treats
  // null as "skip validators", so the value passes straight through.
  @IsOptional()
  @IsString()
  parentId?: string | null;
}
