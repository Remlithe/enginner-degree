/* eslint-disable max-len */
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");

// Define your secret
const stripeKey = defineSecret("STRIPE_API_KEY");

admin.initializeApp();

exports.createCustomer = onCall({secrets: [stripeKey]}, async (request) => {
  try {
    const stripe = require("stripe")(stripeKey.value());
    const data = request.data;

    // Create a customer
    const customer = await stripe.customers.create({
      email: data.email,
      name: data.name,
    });

    console.log(`Customer created with ID: ${customer.id}`);


    try {
      // Use Stripe's test token
      const clonedPaymentMethod = await stripe.paymentMethods.create({
        type: "card",
        card: {
          token: "tok_visa",
        },
      });

      // Attach the payment method to the customer
      await stripe.paymentMethods.attach(clonedPaymentMethod.id, {
        customer: customer.id,
      });

      // Set as default payment method
      await stripe.customers.update(customer.id, {
        invoice_settings: {
          default_payment_method: clonedPaymentMethod.id,
        },
      });

      console.log(`Created and attached payment ${clonedPaymentMethod.id}`);

      return {
        customerId: customer.id,
        paymentMethodId: clonedPaymentMethod.id,
      };
    } catch (paymentError) {
      console.error("Error with payment method:", paymentError);
      // Return the customer ID even if there's an error
      return {
        customerId: customer.id,
        paymentMethodId: null,
      };
    }
  } catch (error) {
    console.error("Error creating customer:", error);
    throw new Error(error.message);
  }
});
exports.createPaymentIntent = onCall({secrets: [stripeKey]}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Musisz być zalogowany.");
  }

  const stripe = require("stripe")(stripeKey.value());
  // Odbieramy dane. WAŻNE: Odbieramy 'email', bo telefon go wysyła
  const {amount, currency, ownerStripeId, email, customerId: paramCustomerId} = request.data;

  try {
    let finalCustomerId = paramCustomerId;

    // JEŚLI TELEFON WYSŁAŁ EMAIL, A NIE ID -> ZNAJDŹ ID W STRIPE
    if (!finalCustomerId && email) {
      const existingCustomers = await stripe.customers.list({email: email, limit: 1});
      if (existingCustomers.data.length > 0) {
        finalCustomerId = existingCustomers.data[0].id;
      } else {
        const newCustomer = await stripe.customers.create({email: email});
        finalCustomerId = newCustomer.id;
      }
    }

    if (!finalCustomerId) {
      throw new HttpsError("invalid-argument", "Brak ID klienta (customerId) lub Emaila.");
    }

    // A. Klucz tymczasowy (wymagany przez aplikację)
    const ephemeralKey = await stripe.ephemeralKeys.create(
        {customer: finalCustomerId}, // <-- Teraz to na pewno nie będzie puste
        {apiVersion: "2023-10-16"},
    );

    // B. Płatność (z transferem do Ownera)
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency || "usd",
      customer: finalCustomerId,
      transfer_data: {
        destination: ownerStripeId,
      },
      on_behalf_of: ownerStripeId,
      application_fee_amount: Math.round(amount * 0.1),
      automatic_payment_methods: {enabled: true},
    });

    return {
      paymentIntent: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: finalCustomerId,
    };
  } catch (error) {
    console.error("Stripe Error:", error);
    throw new HttpsError("internal", error.message);
  }
});
