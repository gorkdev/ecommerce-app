import { IsOptional, IsString } from 'class-validator';

export class CheckoutDto {
  // Optional for now: address management is a later milestone. When supplied
  // it must reference an address owned by the current user.
  @IsOptional()
  @IsString()
  addressId?: string;
}
