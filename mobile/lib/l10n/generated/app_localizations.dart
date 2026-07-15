import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Storefront'**
  String get appTitle;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @browseProducts.
  ///
  /// In en, this message translates to:
  /// **'Browse products'**
  String get browseProducts;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server.'**
  String get networkError;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @discountWithCode.
  ///
  /// In en, this message translates to:
  /// **'Discount ({code})'**
  String discountWithCode(String code);

  /// No description provided for @nItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String nItems(num count);

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @noLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'No longer available'**
  String get noLongerAvailable;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue shopping.'**
  String get signInSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @noAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccountCta;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It only takes a moment.'**
  String get registerSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @passwordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get passwordHelper;

  /// No description provided for @haveAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccountCta;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @validationEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address.'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password.'**
  String get validationPasswordRequired;

  /// No description provided for @validationLoginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get validationLoginPasswordRequired;

  /// No description provided for @validationNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get validationNameRequired;

  /// No description provided for @validationUseAtLeast.
  ///
  /// In en, this message translates to:
  /// **'Use at least {count} characters.'**
  String validationUseAtLeast(int count);

  /// No description provided for @validationUseAtMost.
  ///
  /// In en, this message translates to:
  /// **'Use at most {count} characters.'**
  String validationUseAtMost(int count);

  /// No description provided for @fieldAtLeast.
  ///
  /// In en, this message translates to:
  /// **'At least {count} characters'**
  String fieldAtLeast(int count);

  /// No description provided for @fieldAtMost.
  ///
  /// In en, this message translates to:
  /// **'At most {count} characters'**
  String fieldAtMost(int count);

  /// No description provided for @countryFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Two letters, like TR'**
  String get countryFormatHint;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get searchProducts;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @sortPriceLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLowHigh;

  /// No description provided for @sortPriceHighLow.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHighLow;

  /// No description provided for @priceFilter.
  ///
  /// In en, this message translates to:
  /// **'Price filter'**
  String get priceFilter;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My orders'**
  String get myOrders;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCategories;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @noProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the filters.'**
  String get noProductsHint;

  /// No description provided for @couldNotLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Could not load more products.'**
  String get couldNotLoadMore;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get priceRange;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minLabel;

  /// No description provided for @maxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxLabel;

  /// No description provided for @minExceedsMax.
  ///
  /// In en, this message translates to:
  /// **'The minimum cannot exceed the maximum.'**
  String get minExceedsMax;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get addToCart;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get addedToCart;

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'View cart'**
  String get viewCart;

  /// No description provided for @productUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This product is no longer available.'**
  String get productUnavailable;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFromFavorites;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @nReviews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String nReviews(num count);

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Everything you add ends up here.'**
  String get cartEmptyHint;

  /// No description provided for @clearCart.
  ///
  /// In en, this message translates to:
  /// **'Clear cart'**
  String get clearCart;

  /// No description provided for @clearCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear the cart?'**
  String get clearCartTitle;

  /// No description provided for @clearCartBody.
  ///
  /// In en, this message translates to:
  /// **'Every item will be removed.'**
  String get clearCartBody;

  /// No description provided for @onlyNLeftInStock.
  ///
  /// In en, this message translates to:
  /// **'Only {count} left in stock'**
  String onlyNLeftInStock(int count);

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @checkoutEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add something before checking out.'**
  String get checkoutEmptyHint;

  /// No description provided for @noDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'No delivery address yet.'**
  String get noDeliveryAddress;

  /// No description provided for @manageAddresses.
  ///
  /// In en, this message translates to:
  /// **'Manage addresses'**
  String get manageAddresses;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponCode;

  /// No description provided for @removeCoupon.
  ///
  /// In en, this message translates to:
  /// **'Remove coupon'**
  String get removeCoupon;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @paymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment not completed'**
  String get paymentNotCompleted;

  /// No description provided for @paymentPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Order #{reference} is placed and waiting for its payment of {amount}.'**
  String paymentPendingBody(String reference, String amount);

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get payNow;

  /// No description provided for @backToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Back to the catalog'**
  String get backToCatalog;

  /// No description provided for @paymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get paymentReceived;

  /// No description provided for @paymentSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Order #{reference} — {amount}. We are preparing it now.'**
  String paymentSuccessBody(String reference, String amount);

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue shopping'**
  String get continueShopping;

  /// No description provided for @viewMyOrders.
  ///
  /// In en, this message translates to:
  /// **'View my orders'**
  String get viewMyOrders;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @noOrdersHint.
  ///
  /// In en, this message translates to:
  /// **'Everything you buy shows up here.'**
  String get noOrdersHint;

  /// No description provided for @orderRef.
  ///
  /// In en, this message translates to:
  /// **'Order #{reference}'**
  String orderRef(String reference);

  /// No description provided for @placedOn.
  ///
  /// In en, this message translates to:
  /// **'Placed {date}'**
  String placedOn(String date);

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// No description provided for @statusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get statusPreparing;

  /// No description provided for @statusShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get statusShipped;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @stepOrderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get stepOrderPlaced;

  /// No description provided for @stepPaymentConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get stepPaymentConfirmed;

  /// No description provided for @orderCancelledBanner.
  ///
  /// In en, this message translates to:
  /// **'This order was cancelled.'**
  String get orderCancelledBanner;

  /// No description provided for @orderRefundedBanner.
  ///
  /// In en, this message translates to:
  /// **'This order was refunded.'**
  String get orderRefundedBanner;

  /// No description provided for @nothingSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get nothingSavedYet;

  /// No description provided for @favoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a product to keep it here.'**
  String get favoritesHint;

  /// No description provided for @addresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageTurkish;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddress;

  /// No description provided for @noAddressesYet.
  ///
  /// In en, this message translates to:
  /// **'No addresses yet'**
  String get noAddressesYet;

  /// No description provided for @noAddressesHint.
  ///
  /// In en, this message translates to:
  /// **'Save one to speed through checkout.'**
  String get noAddressesHint;

  /// No description provided for @defaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultBadge;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @deleteAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this address?'**
  String get deleteAddressTitle;

  /// No description provided for @newAddress.
  ///
  /// In en, this message translates to:
  /// **'New address'**
  String get newAddress;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @addressLine.
  ///
  /// In en, this message translates to:
  /// **'Address line'**
  String get addressLine;

  /// No description provided for @addressLine2Optional.
  ///
  /// In en, this message translates to:
  /// **'Address line 2 (optional)'**
  String get addressLine2Optional;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @postalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get postalCode;

  /// No description provided for @countryIso.
  ///
  /// In en, this message translates to:
  /// **'Country (ISO-2)'**
  String get countryIso;

  /// No description provided for @useAsDefaultAddress.
  ///
  /// In en, this message translates to:
  /// **'Use as default address'**
  String get useAsDefaultAddress;

  /// No description provided for @thisIsDefaultAddress.
  ///
  /// In en, this message translates to:
  /// **'This is your default address.'**
  String get thisIsDefaultAddress;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get saveAddress;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeReview;

  /// No description provided for @editYourReview.
  ///
  /// In en, this message translates to:
  /// **'Edit your review'**
  String get editYourReview;

  /// No description provided for @beFirstToReview.
  ///
  /// In en, this message translates to:
  /// **'Purchased this product? Be the first to review it.'**
  String get beFirstToReview;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get submitReview;

  /// No description provided for @deleteMyReview.
  ///
  /// In en, this message translates to:
  /// **'Delete my review'**
  String get deleteMyReview;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name} 👋'**
  String greeting(String name);

  /// No description provided for @promoBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'10% off your first order'**
  String get promoBannerTitle;

  /// No description provided for @promoBannerBody.
  ///
  /// In en, this message translates to:
  /// **'Use code {code} at checkout'**
  String promoBannerBody(String code);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
