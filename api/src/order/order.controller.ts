import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { OrderService } from './order.service';
import { CheckoutDto } from './dto/checkout.dto';

@UseGuards(JwtAuthGuard)
@Controller('orders')
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Post('checkout')
  checkout(@CurrentUser() user: AuthUser, @Body() dto: CheckoutDto) {
    return this.orderService.checkout(user.userId, dto);
  }

  @Get()
  findMine(@CurrentUser() user: AuthUser) {
    return this.orderService.findMine(user.userId);
  }

  @Get(':id')
  findOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.orderService.findOneForUser(user.userId, id);
  }
}
