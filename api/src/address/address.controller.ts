import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { AddressService } from './address.service';
import { CreateAddressDto } from './dto/create-address.dto';
import { UpdateAddressDto } from './dto/update-address.dto';

@UseGuards(JwtAuthGuard)
@Controller('addresses')
export class AddressController {
  constructor(private readonly addressService: AddressService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.addressService.list(user.userId);
  }

  @Post()
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateAddressDto) {
    return this.addressService.create(user.userId, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateAddressDto,
  ) {
    return this.addressService.update(user.userId, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.addressService.remove(user.userId, id);
  }
}
