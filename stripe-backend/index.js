const express = require('express');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();

// Middleware
app.use(cors({
  origin: '*', // En production, remplacez par votre domaine Flutter
  credentials: true
}));
app.use(express.json());

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Stripe Backend API is running',
    timestamp: new Date().toISOString()
  });
});

// Endpoint pour créer un PaymentIntent
app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency = 'eur', metadata = {} } = req.body;

    // Validation
    if (!amount || amount <= 0) {
      return res.status(400).json({
        error: 'Le montant est requis et doit être supérieur à 0'
      });
    }

    // Convertir le montant en centimes (Stripe utilise les plus petites unités)
    const amountInCents = Math.round(amount * 100);

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

    // Retourner le clientSecret
    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Erreur lors de la création du PaymentIntent:', error);
    res.status(500).json({
      error: 'Erreur lors de la création du PaymentIntent',
      message: error.message,
    });
  }
});

// Gestion des erreurs
app.use((err, req, res, next) => {
  console.error('Erreur serveur:', err);
  res.status(500).json({
    error: 'Erreur serveur interne',
    message: err.message,
  });
});

// Port
const PORT = process.env.PORT || 3000;

// Démarrer le serveur (uniquement pour le développement local)
if (process.env.NODE_ENV !== 'production') {
  app.listen(PORT, () => {
    console.log(`🚀 Serveur Stripe Backend démarré sur le port ${PORT}`);
    console.log(`📝 Endpoint: http://localhost:${PORT}/create-payment-intent`);
  });
}

// Export pour Vercel/Netlify
module.exports = app;

