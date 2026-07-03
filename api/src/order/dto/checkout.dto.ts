import { IsOptional, IsString, Length } from 'class-validator';

export class CheckoutDto {
  // Optional for now: address management is a later milestone. When supplied
  // it must reference an address owned by the current user.
  @IsOptional()
  @IsString()
  addressId?: string;

  // Optional discount code; validated and redeemed atomically at checkout.
  @IsOptional()
  @IsString()
  @Length(3, 40)
  couponCode?: string;
}
