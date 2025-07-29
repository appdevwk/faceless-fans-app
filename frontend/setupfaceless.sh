#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Directory Variables
BASE_DIR="$HOME/twisted-tshirt-co"
BACKEND_DIR="$BASE_DIR/backend"
FRONTEND_DIR="$BASE_DIR/frontend"
BACKEND_GITHUB_USER="appdevwk"
BACKEND_GITHUB_REPO="faceless-fans-backend"
FRONTEND_GITHUB_USER="appdevwk"
FRONTEND_GITHUB_REPO="faceless-fans-frontend"
VERCEL_TOKEN="your-vercel-token" # Replace with your Vercel token
MONGODB_URI="mongodb://localhost:27017/facelessfans" # Update with your MongoDB Atlas URI if needed
JWT_SECRET="your-secure-random-key" # Replace with a secure key (e.g., openssl rand -base64 32)

# Prompt for Stripe Keys and Webhook Secret
echo -e "${GREEN}Please enter your Stripe Publishable Key (e.g., pk_test_...): ${NC}"
read -s STRIPE_PUBLISHABLE_KEY
echo -e "${GREEN}Please enter your Stripe Secret Key (e.g., sk_test_...): ${NC}"
read -s STRIPE_SECRET_KEY
echo -e "${GREEN}Please enter your Stripe Webhook Secret (e.g., whsec_...): ${NC}"
read -s STRIPE_WEBHOOK_SECRET

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo privileges.${NC}"
  exit 1
fi

echo -e "${GREEN}Starting combined setup for Twisted Tshirt Co and Faceless at 03:13 PM EDT, July 20, 2025...${NC}"

# 1. Update system and install dependencies
echo -e "${GREEN}Updating system and installing dependencies...${NC}"
apt-get update && apt-get install -y curl git nodejs npm mongodb-server

# 2. Install Vercel CLI
echo -e "${GREEN}Installing Vercel CLI...${NC}"
npm install -g vercel @vue/cli

# 3. Create root package.json with build scripts
echo -e "${GREEN}Creating root package.json with build scripts...${NC}"
cd "$BASE_DIR"
cat << 'EOF' > package.json
{
  "name": "twisted-tshirt-co",
  "version": "1.0.0",
  "scripts": {
    "build": "npm run build:backend && npm run build:frontend",
    "build:backend": "cd backend && npm install && npm run build",
    "build:frontend": "cd frontend && npm install && npm run build",
    "start": "cd backend && node server.js"
  },
  "private": true
}
EOF

# --- Backend Setup ---

echo -e "${GREEN}Setting up backend in $BACKEND_DIR...${NC}"

# 4. Create backend directory and navigate
mkdir -p "$BACKEND_DIR" && cd "$BACKEND_DIR"

# 5. Initialize backend package.json
echo -e "${GREEN}Initializing backend package.json...${NC}"
npm init -y

# 6. Install backend dependencies including Stripe
echo -e "${GREEN}Installing backend dependencies...${NC}"
npm install express mongoose jsonwebtoken bcryptjs cors stripe

# 7. Create backend package.json with build script
cat << 'EOF' > package.json
{
  "name": "faceless-backend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Backend build: No transpilation needed, copying files' && cp server.js dist/ || mkdir dist && cp server.js dist/",
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.17.1",
    "mongoose": "^6.0.0",
    "jsonwebtoken": "^8.5.1",
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "stripe": "^8.0.0"
  }
}
EOF

# 8. Create server.js with enhanced webhook handling
echo -e "${GREEN}Creating server.js with Stripe webhook handling...${NC}"
cat << 'EOF' > server.js
const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY || 'your-stripe-secret-key');

const app = express();
app.use(express.json());
app.use(cors());

// Middleware for raw body parsing required for webhook
app.use('/api/webhook', express.raw({ type: 'application/json' }));

const PORT = process.env.PORT || 5000;

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/facelessfans', {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => console.log('MongoDB connected'))
  .catch(err => console.log(err));

const userSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
});
const User = mongoose.model('User', userSchema);

const influencerSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  name: { type: String, required: true },
  backgroundColor: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
});
const Influencer = mongoose.model('Influencer', influencerSchema);

const orderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  items: [{ productId: String, quantity: Number, price: Number }],
  total: Number,
  status: { type: String, default: 'pending' },
  stripeSessionId: String,
  createdAt: { type: Date, default: Date.now },
});
const Order = mongoose.model('Order', orderSchema);

app.post('/api/register', async (req, res) => {
  const { username, email, password } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ username, email, password: hashedPassword });
    await user.save();
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET || 'your-secret-key');
    res.status(201).json({ token });
  } catch (error) {
    res.status(400).json({ message: 'User already exists' });
  }
});

app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await User.findOne({ email });
    if (user && await bcrypt.compare(password, user.password)) {
      const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET || 'your-secret-key');
      res.json({ token });
    } else {
      res.status(401).json({ message: 'Invalid credentials' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/influencers', async (req, res) => {
  const { userId, name, backgroundColor } = req.body;
  try {
    const influencer = new Influencer({ userId, name, backgroundColor });
    await influencer.save();
    res.status(201).json(influencer);
  } catch (error) {
    res.status(500).json({ message: 'Error creating influencer' });
  }
});

app.get('/api/influencers/:userId', async (req, res) => {
  try {
    const influencers = await Influencer.find({ userId: req.params.userId });
    res.json(influencers);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching influencers' });
  }
});

app.post('/api/create-checkout-session', async (req, res) => {
  const { items, userId } = req.body;
  const lineItems = items.map(item => ({
    price_data: {
      currency: 'usd',
      product_data: { name: item.productId },
      unit_amount: item.price * 100, // Convert to cents
    },
    quantity: item.quantity,
  }));

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: lineItems,
    mode: 'payment',
    success_url: 'http://localhost:3000/success',
    cancel_url: 'http://localhost:3000/cancel',
    metadata: { userId },
  });

  const order = new Order({ userId, items, total: items.reduce((sum, item) => sum + item.price * item.quantity, 0), stripeSessionId: session.id });
  await order.save();

  res.json({ id: session.id });
});

app.post('/api/webhook', (req, res) => {
  const sig = req.headers['stripe-signature'];
  let event;

  try {
    event = stripe.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET || 'your-webhook-secret');
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  switch (event.type) {
    case 'checkout.session.completed':
      const session = event.data.object;
      handlePaymentSuccess(session);
      break;
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      // Additional handling if using Payment Intents directly
      break;
    default:
      console.log(`Unhandled event type ${event.type}`);
  }

  res.json({ received: true });
});

async function handlePaymentSuccess(session) {
  const order = await Order.findOne({ stripeSessionId: session.id });
  if (order) {
    order.status = 'completed';
    await order.save();
    console.log('Order confirmed:', order._id);
    // Add email notification or other actions here
  }
}

module.exports = app;
EOF

# 9. Create vercel.json for backend
echo -e "${GREEN}Creating vercel.json for backend...${NC}"
cat << 'EOF' > vercel.json
{
  "version": 2,
  "builds": [
    {
      "src": "dist/server.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "dist/server.js"
    }
  ],
  "env": {
    "STRIPE_SECRET_KEY": "@stripe-secret-key",
    "STRIPE_WEBHOOK_SECRET": "@stripe-webhook-secret"
  }
}
EOF

# 10. Create GitHub Actions workflow for backend
echo -e "${GREEN}Creating GitHub Actions workflow for backend...${NC}"
mkdir -p .github/workflows
cat << 'EOF' > .github/workflows/deploy.yml
name: Deploy Backend to Vercel

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Install Vercel CLI
        run: npm install -g vercel@latest

      - name: Build Backend
        run: cd backend && npm run build

      - name: Pull Vercel Environment Information
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}

      - name: Deploy to Vercel
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
EOF

# 11. Initialize Git and push backend to GitHub
echo -e "${GREEN}Setting up Git and pushing backend to GitHub...${NC}"
git init
git add .
git commit -m "Initial backend setup with npm build script (03:13 PM EDT, July 20, 2025)"
git remote add origin https://github.com/$BACKEND_GITHUB_USER/$BACKEND_GITHUB_REPO.git
git push -u origin main

# --- Frontend Setup ---

echo -e "${GREEN}Setting up frontend in $FRONTEND_DIR...${NC}"

# 12. Create frontend directory and navigate
cd "$HOME" && mkdir -p "$FRONTEND_DIR" && cd "$FRONTEND_DIR"

# 13. Initialize frontend package.json
echo -e "${GREEN}Initializing frontend package.json...${NC}"
npm init -y

# 14. Install frontend dependencies
echo -e "${GREEN}Installing frontend dependencies...${NC}"
npm install vue@3 vue-router@4 @vue/cli-service @stripe/stripe-js axios jsonwebtoken lodash

# 15. Create vite.config.js for Vite build
echo -e "${GREEN}Creating vite.config.js...${NC}"
cat << 'EOF' > vite.config.js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: '../dist', // Output to root dist for Vercel
  }
})
EOF

# 16. Create or modify frontend files with Stripe integration
echo -e "${GREEN}Creating detailed frontend components with Stripe and faceless features...${NC}"

# src/App.vue (unchanged)
cat << 'EOF' > src/App.vue
<template>
  <div class="container">
    <header>
      <h1>Faceless Fans Creator</h1>
      <nav>
        <router-link to="/signup">Sign Up</router-link> |
        <router-link to="/creator">Create</router-link> |
        <router-link to="/dashboard">Dashboard</router-link> |
        <router-link to="/checkout">Checkout</router-link>
      </nav>
    </header>
    <keep-alive>
      <router-view></router-view>
    </keep-alive>
    <div v-if="adsVisible" id="ads" class="section">
      <h2>Advertising Opportunities</h2>
      <ul>
        <li><a href="https://facelessfans.com/product1" target="_blank">Product 1 - $37.00</a></li>
        <li><a href="https://affiliate.com/product2?ref=creator123" target="_blank">Product 2 - Affiliate Link</a></li>
        <li><a href="https://facelessfans.com/guide" target="_blank">AI Fans Guide - $37.00</a></li>
      </ul>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';
export default {
  setup() {
    const adsVisible = ref(false);
    return { adsVisible };
  }
};
</script>

<style scoped>
/* Add styles here or in styles.css */
</style>
EOF

# src/views/Checkout.vue with Stripe
cat << 'EOF' > src/views/Checkout.vue
<template>
  <div class="section">
    <h2>Checkout</h2>
    <div id="payment-element">
      <!-- Stripe Elements will mount here -->
    </div>
    <button @click="pay">Pay Now</button>
  </div>
</template>

<script>
import { loadStripe } from '@stripe/stripe-js';
import { ref, onMounted } from 'vue';

export default {
  setup() {
    const stripe = ref(null);
    const elements = ref(null);
    const clientSecret = ref(null);

    onMounted(async () => {
      stripe.value = await loadStripe('your-stripe-publishable-key');
      const response = await fetch('http://localhost:5000/api/create-checkout-session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items: [{ productId: 'T-Shirt', quantity: 1, price: 29.99 }], userId: localStorage.getItem('token') ? jwt.decode(localStorage.getItem('token')).id : null }),
      });
      const { id } = await response.json();
      clientSecret.value = id;

      elements.value = stripe.value.elements();
      const paymentElement = elements.value.create('payment');
      paymentElement.mount('#payment-element');
    });

    const pay = async () => {
      const { error } = await stripe.value.confirmPayment({
        elements: elements.value,
        confirmParams: {
          return_url: 'http://localhost:3000/success',
        },
      });

      if (error) {
        alert(error.message);
      } else {
        alert('Payment succeeded!');
      }
    };

    return { pay };
  }
};
</script>
EOF

# src/views/Signup.vue (unchanged)
cat << 'EOF' > src/views/Signup.vue
<template>
  <div class="section">
    <h2>Sign Up</h2>
    <form @submit.prevent="handleSignup">
      <input v-model="username" type="text" placeholder="Username" required><br>
      <input v-model="email" type="email" placeholder="Email" required><br>
      <input v-model="password" type="password" placeholder="Password" required><br>
      <button type="submit">Sign Up</button>
    </form>
  </div>
</template>

<script>
import { ref } from 'vue';
import jwt from 'jsonwebtoken';
export default {
  setup() {
    const username = ref('');
    const email = ref('');
    const password = ref('');

    const handleSignup = async () => {
      const response = await fetch('http://localhost:5000/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.value, email: email.value, password: password.value }),
      });
      if (response.ok) {
        const { token } = await response.json();
        localStorage.setItem('token', token);
        this.$router.push('/creator');
        loadInfluencers();
      } else {
        alert('Registration failed');
      }
    };

    return { username, email, password, handleSignup };
  }
};
</script>
EOF

# src/views/Creator.vue (unchanged)
cat << 'EOF' > src/views/Creator.vue
<template>
  <div class="section">
    <h2>Design Your Influencer</h2>
    <div class="creator-form">
      <input v-model="name" type="text" placeholder="Influencer Name" required @input="previewInfluencer">
      <select v-model="color" @change="previewInfluencer">
        <option v-for="c in colors" :key="c" :value="c">{{ c }}</option>
      </select>
      <input type="file" @change="previewImage" accept="image/*">
      <button @click="generateInfluencer">Generate & Save</button>
      <div id="influencerPreview" class="preview-box" ref="preview"></div>
    </div>
  </div>
</template>

<script>
import { ref, onMounted, debounce } from 'vue';
import jwt from 'jsonwebtoken';
import _ from 'lodash';

export default {
  setup() {
    const name = ref('');
    const color = ref('red');
    const colors = ['red', 'blue', 'green', 'purple'];
    const preview = ref(null);

    const previewInfluencer = debounce(() => {
      if (preview.value) {
        preview.value.innerHTML = `<h3>${name.value || 'Unnamed'}</h3><div style="background-color: ${color.value}; width: 200px; height: 200px; margin: 0 auto;"></div>`;
      }
    }, 300);

    const previewImage = (e) => {
      const file = e.target.files[0];
      if (file && preview.value) {
        const reader = new FileReader();
        reader.onload = (e) => {
          const img = new Image();
          img.onload = () => {
            const canvas = document.createElement('canvas');
            const maxSize = 200;
            const scale = Math.min(maxSize / img.width, maxSize / img.height);
            canvas.width = img.width * scale;
            canvas.height = img.height * scale;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
            preview.value.innerHTML = preview.value.innerHTML.replace(/<img[^>]*>/, '') + `<img src="${canvas.toDataURL()}" style="max-width: 100%; max-height: 100%;">`;
          };
          img.src = e.target.result;
        };
        reader.readAsDataURL(file);
      }
    };

    const generateInfluencer = async () => {
      const token = localStorage.getItem('token');
      const userId = jwt.decode(token).id;
      const response = await fetch('http://localhost:5000/api/influencers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ userId, name: name.value, backgroundColor: color.value }),
      });
      if (response.ok) {
        this.$router.push('/ads');
        loadInfluencers();
      } else {
        alert('Failed to save influencer');
      }
    };

    onMounted(() => {
      preview.value = document.getElementById('influencerPreview');
    });

    return { name, color, colors, previewInfluencer, generateInfluencer, previewImage };
  }
};
</script>
EOF

# src/views/Dashboard.vue (unchanged)
cat << 'EOF' > src/views/Dashboard.vue
<template>
  <div class="section">
    <h2>Your Influencers</h2>
    <div id="influencerList">
      <div v-for="influencer in influencers" :key="influencer._id" v-memo="[influencer.name, influencer.backgroundColor]" class="influencer-card">
        <h4>{{ influencer.name }}</h4>
        <div :style="{ backgroundColor: influencer.backgroundColor, width: '100px', height: '100px', margin: '0 auto' }"></div>
        <p>Created: {{ new Date(influencer.createdAt).toLocaleDateString() }}</p>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import jwt from 'jsonwebtoken';

export default {
  setup() {
    const influencers = ref([]);

    const loadInfluencers = async () => {
      const token = localStorage.getItem('token');
      const userId = jwt.decode(token).id;
      const response = await fetch('http://localhost:5000/api/influencers/' + userId, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (response.ok) {
        influencers.value = await response.json();
      }
    };

    onMounted(loadInfluencers);

    return { influencers };
  }
};
</script>
EOF

# src/router/index.js
cat << 'EOF' > src/router/index.js
import { createRouter, createWebHistory } from 'vue-router';

const routes = [
  { path: '/signup', component: () => import('../views/Signup.vue') },
  { path: '/creator', component: () => import('../views/Creator.vue') },
  { path: '/dashboard', component: () => import('../views/Dashboard.vue') },
  { path: '/checkout', component: () => import('../views/Checkout.vue') },
  { path: '/ads', beforeEnter: (to, from) => { location.href = '/#ads'; } }
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

export default router;
EOF

# Update main.js to include router and Devtools
echo -e "${GREEN}Creating main.js...${NC}"
cat << 'EOF' > src/main.js
import { createApp } from 'vue';
import App from './App.vue';
import router from './router';

createApp(App).use(router).mount('#app');
EOF

# Replace Stripe keys in Checkout.vue
sed -i "s|your-stripe-publishable-key|$STRIPE_PUBLISHABLE_KEY|" src/views/Checkout.vue

# 17. Initialize Git and push frontend to GitHub
echo -e "${GREEN}Setting up Git and pushing frontend to GitHub...${NC}"
cd "$FRONTEND_DIR"
git init
git add .
git commit -m "Initial detailed Vue.js frontend setup with npm build script (03:13 PM EDT, July 20, 2025)"
git remote add origin https://github.com/$FRONTEND_GITHUB_USER/$FRONTEND_GITHUB_REPO.git
git push -u origin main

# 18. Build the project
echo -e "${GREEN}Building the project...${NC}"
cd "$BASE_DIR"
npm run build

# 19. Log in to Vercel and deploy
echo -e "${GREEN}Logging into Vercel and deploying...${NC}"
vercel login --token $VERCEL_TOKEN
vercel --prod

# 20. Set environment variables on Vercel
echo -e "${GREEN}Setting environment variables on Vercel...${NC}"
vercel env add JWT_SECRET --token $VERCEL_TOKEN
echo $JWT_SECRET | vercel env add JWT_SECRET --token $VERCEL_TOKEN
vercel env add MONGODB_URI $MONGODB_URI --token $VERCEL_TOKEN
vercel env add STRIPE_SECRET_KEY $STRIPE_SECRET_KEY --token $VERCEL_TOKEN
vercel env add STRIPE_WEBHOOK_SECRET $STRIPE_WEBHOOK_SECRET --token $VERCEL_TOKEN

# 21. Start MongoDB
echo -e "${GREEN}Starting MongoDB...${NC}"
systemctl start mongodb || service mongodb start

echo -e "${GREEN}Combined setup and build completed! Backend at $BACKEND_DIR and frontend at $FRONTEND_DIR with Stripe webhook handling. Deployment URLs will be shown after Vercel deployment.${NC}"
