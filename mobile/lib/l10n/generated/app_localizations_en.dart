// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Storefront';

  @override
  String get tryAgain => 'Try again';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get apply => 'Apply';

  @override
  String get add => 'Add';

  @override
  String get change => 'Change';

  @override
  String get edit => 'Edit';

  @override
  String get clear => 'Clear';

  @override
  String get remove => 'Remove';

  @override
  String get browseProducts => 'Browse products';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get networkError => 'No connection to the server.';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get total => 'Total';

  @override
  String get discount => 'Discount';

  @override
  String discountWithCode(String code) {
    return 'Discount ($code)';
  }

  @override
  String nItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get noLongerAvailable => 'No longer available';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in to continue shopping.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccountCta => 'Don\'t have an account? Sign up';

  @override
  String get createAccount => 'Create account';

  @override
  String get registerSubtitle => 'It only takes a moment.';

  @override
  String get fullName => 'Full name';

  @override
  String get passwordHelper => 'At least 8 characters.';

  @override
  String get haveAccountCta => 'Already have an account? Sign in';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signOut => 'Sign out';

  @override
  String get validationEmailRequired => 'Enter your email address.';

  @override
  String get validationEmailInvalid => 'Enter a valid email address.';

  @override
  String get validationPasswordRequired => 'Enter a password.';

  @override
  String get validationLoginPasswordRequired => 'Enter your password.';

  @override
  String get validationNameRequired => 'Enter your name.';

  @override
  String validationUseAtLeast(int count) {
    return 'Use at least $count characters.';
  }

  @override
  String validationUseAtMost(int count) {
    return 'Use at most $count characters.';
  }

  @override
  String fieldAtLeast(int count) {
    return 'At least $count characters';
  }

  @override
  String fieldAtMost(int count) {
    return 'At most $count characters';
  }

  @override
  String get countryFormatHint => 'Two letters, like TR';

  @override
  String get searchProducts => 'Search products';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get sort => 'Sort';

  @override
  String get sortNewest => 'Newest';

  @override
  String get sortPriceLowHigh => 'Price: low to high';

  @override
  String get sortPriceHighLow => 'Price: high to low';

  @override
  String get priceFilter => 'Price filter';

  @override
  String get cart => 'Cart';

  @override
  String get profile => 'Profile';

  @override
  String get myOrders => 'My orders';

  @override
  String get favorites => 'Favorites';

  @override
  String get allCategories => 'All';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get noProductsHint => 'Try a different search or clear the filters.';

  @override
  String get couldNotLoadMore => 'Could not load more products.';

  @override
  String get priceRange => 'Price range';

  @override
  String get minLabel => 'Min';

  @override
  String get maxLabel => 'Max';

  @override
  String get minExceedsMax => 'The minimum cannot exceed the maximum.';

  @override
  String get clearFilter => 'Clear filter';

  @override
  String get product => 'Product';

  @override
  String get inStock => 'In stock';

  @override
  String get description => 'Description';

  @override
  String get addToCart => 'Add to cart';

  @override
  String get addedToCart => 'Added to cart';

  @override
  String get viewCart => 'View cart';

  @override
  String get productUnavailable => 'This product is no longer available.';

  @override
  String get addToFavorites => 'Add to favorites';

  @override
  String get removeFromFavorites => 'Remove from favorites';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String nReviews(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyTitle => 'Your cart is empty';

  @override
  String get cartEmptyHint => 'Everything you add ends up here.';

  @override
  String get clearCart => 'Clear cart';

  @override
  String get clearCartTitle => 'Clear the cart?';

  @override
  String get clearCartBody => 'Every item will be removed.';

  @override
  String onlyNLeftInStock(int count) {
    return 'Only $count left in stock';
  }

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get checkout => 'Checkout';

  @override
  String get checkoutEmptyHint => 'Add something before checking out.';

  @override
  String get noDeliveryAddress => 'No delivery address yet.';

  @override
  String get manageAddresses => 'Manage addresses';

  @override
  String get couponCode => 'Coupon code';

  @override
  String get removeCoupon => 'Remove coupon';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get paymentNotCompleted => 'Payment not completed';

  @override
  String paymentPendingBody(String reference, String amount) {
    return 'Order #$reference is placed and waiting for its payment of $amount.';
  }

  @override
  String get payNow => 'Pay now';

  @override
  String get backToCatalog => 'Back to the catalog';

  @override
  String get paymentReceived => 'Payment received';

  @override
  String paymentSuccessBody(String reference, String amount) {
    return 'Order #$reference — $amount. We are preparing it now.';
  }

  @override
  String get continueShopping => 'Continue shopping';

  @override
  String get viewMyOrders => 'View my orders';

  @override
  String get order => 'Order';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get noOrdersHint => 'Everything you buy shows up here.';

  @override
  String orderRef(String reference) {
    return 'Order #$reference';
  }

  @override
  String placedOn(String date) {
    return 'Placed $date';
  }

  @override
  String get items => 'Items';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusShipped => 'Shipped';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get stepOrderPlaced => 'Order placed';

  @override
  String get stepPaymentConfirmed => 'Payment confirmed';

  @override
  String get orderCancelledBanner => 'This order was cancelled.';

  @override
  String get orderRefundedBanner => 'This order was refunded.';

  @override
  String get nothingSavedYet => 'Nothing saved yet';

  @override
  String get favoritesHint => 'Tap the heart on a product to keep it here.';

  @override
  String get addresses => 'Addresses';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get addAddress => 'Add address';

  @override
  String get noAddressesYet => 'No addresses yet';

  @override
  String get noAddressesHint => 'Save one to speed through checkout.';

  @override
  String get defaultBadge => 'Default';

  @override
  String get setAsDefault => 'Set as default';

  @override
  String get deleteAddressTitle => 'Delete this address?';

  @override
  String get newAddress => 'New address';

  @override
  String get editAddress => 'Edit address';

  @override
  String get phone => 'Phone';

  @override
  String get addressLine => 'Address line';

  @override
  String get addressLine2Optional => 'Address line 2 (optional)';

  @override
  String get district => 'District';

  @override
  String get city => 'City';

  @override
  String get postalCode => 'Postal code';

  @override
  String get countryIso => 'Country (ISO-2)';

  @override
  String get useAsDefaultAddress => 'Use as default address';

  @override
  String get thisIsDefaultAddress => 'This is your default address.';

  @override
  String get saveAddress => 'Save address';

  @override
  String get writeReview => 'Write a review';

  @override
  String get editYourReview => 'Edit your review';

  @override
  String get beFirstToReview =>
      'Purchased this product? Be the first to review it.';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get submitReview => 'Submit review';

  @override
  String get deleteMyReview => 'Delete my review';
}
