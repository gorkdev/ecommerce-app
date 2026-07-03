import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { Roles } from '../auth/decorators/roles.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Role } from '../generated/prisma/client';
import { ProductService } from './product.service';
import { QueryProductDto } from './dto/query-product.dto';

// Admin catalog listing. Unlike the public GET /products (active only), this
// returns every product including inactive/draft ones so the panel can manage
// them. Mutations stay on the ADMIN-guarded routes of ProductController.
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.ADMIN)
@Controller('admin/products')
export class AdminProductController {
  constructor(private readonly productService: ProductService) {}

  @Get()
  findAll(@Query() query: QueryProductDto) {
    return this.productService.findAllForAdmin(query);
  }
}
