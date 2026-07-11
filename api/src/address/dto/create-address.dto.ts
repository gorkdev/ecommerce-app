import {
  IsBoolean,
  IsOptional,
  IsString,
  Length,
} from 'class-validator';

export class CreateAddressDto {
  @IsString()
  @Length(2, 100)
  fullName: string;

  @IsString()
  @Length(7, 20)
  phone: string;

  @IsString()
  @Length(3, 200)
  line1: string;

  @IsOptional()
  @IsString()
  @Length(1, 200)
  line2?: string;

  @IsString()
  @Length(2, 100)
  city: string;

  @IsString()
  @Length(2, 100)
  district: string;

  @IsString()
  @Length(3, 10)
  postalCode: string;

  // ISO 3166-1 alpha-2; the database defaults to TR when omitted.
  @IsOptional()
  @IsString()
  @Length(2, 2)
  country?: string;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}
