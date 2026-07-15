// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Mağaza';

  @override
  String get tryAgain => 'Tekrar dene';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get delete => 'Sil';

  @override
  String get apply => 'Uygula';

  @override
  String get add => 'Ekle';

  @override
  String get change => 'Değiştir';

  @override
  String get edit => 'Düzenle';

  @override
  String get clear => 'Temizle';

  @override
  String get remove => 'Kaldır';

  @override
  String get view => 'Görüntüle';

  @override
  String get browseProducts => 'Ürünlere göz at';

  @override
  String get somethingWentWrong => 'Bir şeyler ters gitti.';

  @override
  String get networkError => 'Sunucuya bağlanılamıyor.';

  @override
  String get subtotal => 'Ara toplam';

  @override
  String get total => 'Toplam';

  @override
  String get discount => 'İndirim';

  @override
  String discountWithCode(String code) {
    return 'İndirim ($code)';
  }

  @override
  String nItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ürün',
      one: '1 ürün',
    );
    return '$_temp0';
  }

  @override
  String get outOfStock => 'Stokta yok';

  @override
  String get noLongerAvailable => 'Artık satışta değil';

  @override
  String get welcomeBack => 'Tekrar hoş geldiniz';

  @override
  String get signInSubtitle => 'Alışverişe devam etmek için giriş yapın.';

  @override
  String get email => 'E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get signIn => 'Giriş yap';

  @override
  String get noAccountCta => 'Hesabınız yok mu? Kayıt olun';

  @override
  String get createAccount => 'Hesap oluştur';

  @override
  String get registerSubtitle => 'Yalnızca bir dakikanızı alır.';

  @override
  String get fullName => 'Ad soyad';

  @override
  String get passwordHelper => 'En az 8 karakter.';

  @override
  String get haveAccountCta => 'Zaten hesabınız var mı? Giriş yapın';

  @override
  String get showPassword => 'Şifreyi göster';

  @override
  String get hidePassword => 'Şifreyi gizle';

  @override
  String get signOut => 'Çıkış yap';

  @override
  String get validationEmailRequired => 'E-posta adresinizi girin.';

  @override
  String get validationEmailInvalid => 'Geçerli bir e-posta adresi girin.';

  @override
  String get validationPasswordRequired => 'Bir şifre girin.';

  @override
  String get validationLoginPasswordRequired => 'Şifrenizi girin.';

  @override
  String get validationNameRequired => 'Adınızı girin.';

  @override
  String validationUseAtLeast(int count) {
    return 'En az $count karakter kullanın.';
  }

  @override
  String validationUseAtMost(int count) {
    return 'En fazla $count karakter kullanın.';
  }

  @override
  String fieldAtLeast(int count) {
    return 'En az $count karakter';
  }

  @override
  String fieldAtMost(int count) {
    return 'En fazla $count karakter';
  }

  @override
  String get countryFormatHint => 'İki harf, örn. TR';

  @override
  String get searchProducts => 'Ürün ara';

  @override
  String get clearSearch => 'Aramayı temizle';

  @override
  String get sort => 'Sırala';

  @override
  String get sortNewest => 'En yeni';

  @override
  String get sortPriceLowHigh => 'Fiyat: düşükten yükseğe';

  @override
  String get sortPriceHighLow => 'Fiyat: yüksekten düşüğe';

  @override
  String get priceFilter => 'Fiyat filtresi';

  @override
  String get cart => 'Sepet';

  @override
  String get profile => 'Profil';

  @override
  String get myOrders => 'Siparişlerim';

  @override
  String get favorites => 'Favoriler';

  @override
  String get allCategories => 'Tümü';

  @override
  String get noProductsFound => 'Ürün bulunamadı';

  @override
  String get noProductsHint =>
      'Farklı bir arama deneyin veya filtreleri temizleyin.';

  @override
  String get couldNotLoadMore => 'Daha fazla ürün yüklenemedi.';

  @override
  String get priceRange => 'Fiyat aralığı';

  @override
  String get minLabel => 'En az';

  @override
  String get maxLabel => 'En çok';

  @override
  String get minExceedsMax => 'En düşük değer en yükseği aşamaz.';

  @override
  String get clearFilter => 'Filtreyi temizle';

  @override
  String get product => 'Ürün';

  @override
  String get inStock => 'Stokta var';

  @override
  String get description => 'Açıklama';

  @override
  String get addToCart => 'Sepete ekle';

  @override
  String get addedToCart => 'Sepete eklendi';

  @override
  String get viewCart => 'Sepeti gör';

  @override
  String get productUnavailable => 'Bu ürün artık satışta değil.';

  @override
  String get addToFavorites => 'Favorilere ekle';

  @override
  String get removeFromFavorites => 'Favorilerden çıkar';

  @override
  String get reviews => 'Değerlendirmeler';

  @override
  String get noReviewsYet => 'Henüz değerlendirme yok';

  @override
  String nReviews(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count değerlendirme',
      one: '1 değerlendirme',
    );
    return '$_temp0';
  }

  @override
  String get cartEmptyTitle => 'Sepetiniz boş';

  @override
  String get cartEmptyHint => 'Eklediğiniz her şey burada görünür.';

  @override
  String get clearCart => 'Sepeti boşalt';

  @override
  String get clearCartTitle => 'Sepet boşaltılsın mı?';

  @override
  String get clearCartBody => 'Tüm ürünler kaldırılacak.';

  @override
  String onlyNLeftInStock(int count) {
    return 'Stokta yalnızca $count adet kaldı';
  }

  @override
  String get decreaseQuantity => 'Adedi azalt';

  @override
  String get increaseQuantity => 'Adedi artır';

  @override
  String get checkout => 'Ödeme';

  @override
  String get checkoutEmptyHint => 'Ödemeden önce sepete bir şeyler ekleyin.';

  @override
  String get noDeliveryAddress => 'Henüz teslimat adresi yok.';

  @override
  String get manageAddresses => 'Adresleri yönet';

  @override
  String get couponCode => 'Kupon kodu';

  @override
  String get removeCoupon => 'Kuponu kaldır';

  @override
  String payAmount(String amount) {
    return '$amount öde';
  }

  @override
  String get paymentNotCompleted => 'Ödeme tamamlanmadı';

  @override
  String paymentPendingBody(String reference, String amount) {
    return '#$reference numaralı sipariş oluşturuldu ve $amount tutarındaki ödemesini bekliyor.';
  }

  @override
  String get payNow => 'Şimdi öde';

  @override
  String get backToCatalog => 'Kataloğa dön';

  @override
  String get paymentReceived => 'Ödeme alındı';

  @override
  String paymentSuccessBody(String reference, String amount) {
    return '#$reference numaralı sipariş — $amount. Şimdi hazırlıyoruz.';
  }

  @override
  String get continueShopping => 'Alışverişe devam et';

  @override
  String get viewMyOrders => 'Siparişlerimi gör';

  @override
  String get order => 'Sipariş';

  @override
  String get noOrdersYet => 'Henüz sipariş yok';

  @override
  String get noOrdersHint => 'Satın aldığınız her şey burada görünür.';

  @override
  String orderRef(String reference) {
    return 'Sipariş #$reference';
  }

  @override
  String placedOn(String date) {
    return '$date tarihinde verildi';
  }

  @override
  String get items => 'Ürünler';

  @override
  String get statusPending => 'Beklemede';

  @override
  String get statusPaid => 'Ödendi';

  @override
  String get statusPreparing => 'Hazırlanıyor';

  @override
  String get statusShipped => 'Kargoda';

  @override
  String get statusDelivered => 'Teslim edildi';

  @override
  String get statusCancelled => 'İptal edildi';

  @override
  String get statusRefunded => 'İade edildi';

  @override
  String get stepOrderPlaced => 'Sipariş alındı';

  @override
  String get stepPaymentConfirmed => 'Ödeme onaylandı';

  @override
  String get orderCancelledBanner => 'Bu sipariş iptal edildi.';

  @override
  String get orderRefundedBanner => 'Bu siparişin ücreti iade edildi.';

  @override
  String get nothingSavedYet => 'Henüz bir şey kaydedilmedi';

  @override
  String get favoritesHint => 'Bir üründeki kalbe dokunun, burada saklansın.';

  @override
  String get addresses => 'Adresler';

  @override
  String get language => 'Dil';

  @override
  String get systemDefault => 'Sistem varsayılanı';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get addAddress => 'Adres ekle';

  @override
  String get noAddressesYet => 'Henüz adres yok';

  @override
  String get noAddressesHint => 'Bir adres kaydedin, ödemeyi hızlandırın.';

  @override
  String get defaultBadge => 'Varsayılan';

  @override
  String get setAsDefault => 'Varsayılan yap';

  @override
  String get deleteAddressTitle => 'Bu adres silinsin mi?';

  @override
  String get newAddress => 'Yeni adres';

  @override
  String get editAddress => 'Adresi düzenle';

  @override
  String get phone => 'Telefon';

  @override
  String get addressLine => 'Adres satırı';

  @override
  String get addressLine2Optional => 'Adres satırı 2 (isteğe bağlı)';

  @override
  String get district => 'İlçe';

  @override
  String get city => 'Şehir';

  @override
  String get postalCode => 'Posta kodu';

  @override
  String get countryIso => 'Ülke (ISO-2)';

  @override
  String get useAsDefaultAddress => 'Varsayılan adres olarak kullan';

  @override
  String get thisIsDefaultAddress => 'Bu, varsayılan adresiniz.';

  @override
  String get saveAddress => 'Adresi kaydet';

  @override
  String get writeReview => 'Değerlendirme yaz';

  @override
  String get editYourReview => 'Değerlendirmenizi düzenleyin';

  @override
  String get beFirstToReview =>
      'Bu ürünü satın aldınız mı? İlk değerlendiren siz olun.';

  @override
  String get commentOptional => 'Yorum (isteğe bağlı)';

  @override
  String get submitReview => 'Değerlendirmeyi gönder';

  @override
  String get deleteMyReview => 'Değerlendirmemi sil';

  @override
  String get navDiscover => 'Keşfet';

  @override
  String get navFavorites => 'Favoriler';

  @override
  String get navCart => 'Sepet';

  @override
  String get navOrders => 'Siparişler';

  @override
  String get navProfile => 'Profil';

  @override
  String greeting(String name) {
    return 'Merhaba $name 👋';
  }

  @override
  String get promoBannerTitle => 'İlk siparişinde %10 indirim';

  @override
  String promoBannerBody(String code) {
    return 'Ödemede $code kodunu kullan';
  }
}
