import {
  Body,
  Controller,
  Delete,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { AuthUser } from '../auth/types/jwt-payload';
import { NotificationService } from './notification.service';
import { RegisterDeviceTokenDto } from './dto/register-device-token.dto';

@UseGuards(JwtAuthGuard)
@Controller('notifications/tokens')
export class NotificationController {
  constructor(private readonly notifications: NotificationService) {}

  @Post()
  register(@CurrentUser() user: AuthUser, @Body() dto: RegisterDeviceTokenDto) {
    return this.notifications.registerToken(user.userId, dto);
  }

  // FCM tokens are URL-safe (alphanumerics plus ":", "-" and "_"), so the
  // token itself can be the path segment.
  @Delete(':token')
  @HttpCode(HttpStatus.NO_CONTENT)
  remove(@CurrentUser() user: AuthUser, @Param('token') token: string) {
    return this.notifications.removeToken(user.userId, token);
  }
}
