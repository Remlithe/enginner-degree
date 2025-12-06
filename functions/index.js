/* eslint-disable max-len */
const {onCall} = require("firebase-functions/v2/https");
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
