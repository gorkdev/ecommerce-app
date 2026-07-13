import {
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export class RegisterDeviceTokenDto {
  // FCM registration token for this install.
  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  token: string;

  @IsIn(['android', 'ios'])
  platform: string;

  // Language the device wants its notifications in. Optional: unknown or
  // missing languages fall back to English server-side.
  @IsOptional()
  @Matches(/^[a-z]{2}$/)
  locale?: string;
}
