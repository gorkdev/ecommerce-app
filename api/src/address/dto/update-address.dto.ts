import {
  IsBoolean,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';

export class UpdateAddressDto {
  @IsOptional()
  @IsString()
  @Length(2, 100)
  fullName?: string;

  @IsOptional()
  @IsString()
  @Length(7, 20)
  phone?: string;

  @IsOptional()
  @IsString()
  @Length(3, 200)
  line1?: string;

  // Explicit null clears the optional second line.
  @IsOptional()
  @IsString()
  @Length(1, 200)
  line2?: string | null;

  @IsOptional()
  @IsString()
  @Length(2, 100)
  city?: string;

  @IsOptional()
  @IsString()
  @Length(2, 100)
  district?: string;

  @IsOptional()
  @IsString()
  @Length(3, 10)
  postalCode?: string;

  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
