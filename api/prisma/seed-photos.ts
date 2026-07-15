// Curated product photography for the demo store (Unsplash License: free to
// use commercially, no attribution required — https://unsplash.com/license).
// Every URL below was verified twice when pinned: an automated 200/image
// check plus a manual look at the actual picture, so the photo genuinely
// shows the product it is attached to. If one ever dies, the seed falls back
// to the generated gradient for that product.

const UNSPLASH_PARAMS = 'w=1200&q=80&auto=format&fit=crop';

function unsplash(id: string): string {
  return `https://images.unsplash.com/${id}?${UNSPLASH_PARAMS}`;
}

/** Photo URLs per product slug, in gallery order. */
export const PRODUCT_PHOTOS: Record<string, string[]> = {
  'aurora-wireless-headphones': [
    unsplash('photo-1505740420928-5e560c06d30e'),
    unsplash('photo-1484704849700-f032a568e944'),
  ],
  'pulse-bluetooth-speaker': [
    unsplash('photo-1608043152269-423dbba4e7e1'),
    unsplash('photo-1589003077984-894e133dabab'),
  ],
  'echo-buds-pro': [
    unsplash('photo-1572569511254-d8f925fe2cbb'),
    unsplash('photo-1590658268037-6bf12165a8df'),
  ],
  'horizon-smartwatch': [
    unsplash('photo-1546868871-7041f2a55e12'),
    unsplash('photo-1523275335684-37898b6baf30'),
  ],
  'stride-fitness-band': [
    unsplash('photo-1576243345690-4e4b79b63288'),
    unsplash('photo-1557935728-e6d1eaabe558'),
  ],
  'nova-smart-ring': [unsplash('photo-1617625802912-cde586faf331')],
  'artisan-coffee-grinder': [unsplash('photo-1610889556528-9a770e32642f')],
  'santoku-chef-knife': [unsplash('photo-1593618998160-e34014e67546')],
  'ceramic-mug-set': [
    unsplash('photo-1514228742587-6b1558fcca3d'),
    unsplash('photo-1544787219-7f47ccb76574'),
  ],
  'cast-iron-skillet': [unsplash('photo-1556910103-1c02745aae4d')],
  'lumen-table-lamp': [
    unsplash('photo-1507473885765-e6ed057f782c'),
    unsplash('photo-1513506003901-1e6a229e2d15'),
  ],
  'woven-throw-blanket': [unsplash('photo-1519643381401-22c77e60520e')],
  'amber-scented-candle': [
    unsplash('photo-1603006905003-be475563bc59'),
    unsplash('photo-1602874801007-bd458bb1b8b6'),
  ],
  'voyager-canvas-backpack': [unsplash('photo-1553062407-98eeb64c6a62')],
  'metro-messenger-bag': [unsplash('photo-1547949003-9792a18a2601')],
  'slimfold-leather-wallet': [unsplash('photo-1627123424574-724758594e93')],
  'titan-water-bottle': [unsplash('photo-1602143407151-7111542de6e8')],
  'trek-travel-organizer': [unsplash('photo-1622560480605-d83c853bc5c3')],
  'studio-monitor-headphones': [
    unsplash('photo-1583394838336-acd977736f90'),
    unsplash('photo-1487215078519-e21cc028cb29'),
  ],
  'aspen-leather-tote': [unsplash('photo-1594223274512-ad4803739b7c')],
  'nordic-lounge-chair': [
    unsplash('photo-1586023492125-27b2c045efd7'),
    unsplash('photo-1567538096630-e0c55bd6374c'),
  ],
  'copenhagen-loveseat': [
    unsplash('photo-1555041469-a586c61ea9bc'),
    unsplash('photo-1493663284031-b7e3aefcae8e'),
  ],
  'pour-over-coffee-kit': [
    unsplash('photo-1512568400610-62da28bc8a13'),
    unsplash('photo-1447933601403-0c6688de566e'),
  ],
  'oak-desk-organizer': [unsplash('photo-1593062096033-9a26b09da705')],
};

/** Downloads one photo; throws on anything that is not a 200 image. */
export async function fetchPhoto(url: string): Promise<Buffer> {
  const response = await fetch(url);
  const contentType = response.headers.get('content-type') ?? '';
  if (response.status !== 200 || !contentType.startsWith('image/')) {
    throw new Error(`unexpected response ${response.status} (${contentType})`);
  }
  return Buffer.from(await response.arrayBuffer());
}
