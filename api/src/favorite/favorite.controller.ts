import {
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { FavoriteService } from './favorite.service';

@UseGuards(JwtAuthGuard)
@Controller('favorites')
export class FavoriteController {
  constructor(private readonly favoriteService: FavoriteService) {}

  @Get()
  list(@CurrentUser() user: AuthUser) {
    return this.favoriteService.list(user.userId);
  }

  @Post(':productId')
  add(@CurrentUser() user: AuthUser, @Param('productId') productId: string) {
    return this.favoriteService.add(user.userId, productId);
  }

  @Delete(':productId')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthUser, @Param('productId') productId: string) {
    return this.favoriteService.remove(user.userId, productId);
  }
}
