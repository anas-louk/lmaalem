const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

/**
 * Serverless function pour créer un PaymentIntent Stripe
 * 
 * Endpoint: POST /api/create-payment-intent
 * 
 * Body:
 * {
 *   "amount": 100.00,
 *   "currency": "eur",
 *   "metadata": { ... }
 * }
 * 
 * Response:
 * {
 *   "clientSecret": "pi_xxx_secret_xxx",
 *   "paymentIntentId": "pi_xxx"
 * }
 */
module.exports = async function handler(req, res) {
  // CORS headers pour permettre les requêtes depuis Flutter
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
  );

  // Gérer les requêtes OPTIONS (preflight)
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // Seulement POST est autorisé
  if (req.method !== 'POST') {
    res.status(405).json({
      error: 'Method not allowed',
      message: 'Only POST requests are supported',
    });
    return;
  }

  try {
    const { amount, currency = 'eur', metadata = {} } = req.body;

    // Validation
    if (!amount || amount <= 0) {
      return res.status(400).json({
        error: 'Invalid amount',
        message: 'Le montant est requis et doit être supérieur à 0',
      });
    }

    // Vérifier que STRIPE_SECRET_KEY est configuré
    if (!process.env.STRIPE_SECRET_KEY) {
      console.error('STRIPE_SECRET_KEY is not configured');
      return res.status(500).json({
        error: 'Server configuration error',
        message: 'Stripe secret key is not configured',
      });
    }

    // Convertir le montant en centimes (Stripe utilise les plus petites unités)
    const amountInCents = Math.round(amount * 100);

    console.log(`Creating PaymentIntent: ${amountInCents} ${currency}`);

    // Créer le PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: currency.toLowerCase(),
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        ...metadata,
        created_at: new Date().toISOString(),
      },
    });

    console.log(`PaymentIntent created: ${paymentIntent.id}`);

    // Retourner le clientSecret
    res.status(200).json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Error creating PaymentIntent:', error);
    res.status(500).json({
      error: 'Error creating PaymentIntent',
      message: error.message || 'An unexpected error occurred',
    });
  }
}

