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

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo privileges.${NC}"
  exit 1
fi

echo -e "${GREEN}Starting combined setup for Twisted Tshirt Co and Faceless at 03:21 PM EDT, July 20, 2025...${NC}"

# 1. Update system and install dependencies
echo -e "${GREEN}Updating system and installing dependencies...${NC}"
apt-get update && apt-get install -y curl git nodejs npm mongodb-server

# 2. Create root package.json with build scripts
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

# 3. Create backend directory and navigate
mkdir -p "$BACKEND_DIR" && cd "$BACKEND_DIR"

# 4. Initialize backend package.json
echo -e "${GREEN}Initializing backend package.json...${NC}"
npm init -y

# 5. Install backend dependencies including Stripe
echo -e "${GREEN}Installing backend dependencies...${NC}"
npm install express mongoose jsonwebtoken bcryptjs cors stripe

# 6. Create backend package.json with build script
cat << 'EOF' > package.json
{
  "name": "faceless-backend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Backend build: No transpilation needed, copying files' && mkdir -p dist && cp server.js dist/ || cp server.js dist/",
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

# 7. Create server.js with enhanced webhook handling
echo -e "${GREEN}Creating server.js with Stripe webhook handling...${NC}"
cat << 'EOF' > server.js
require('dotenv').config();

const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

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
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);
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
      const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET);
      res.json({ token });
    } else {
      res.status(401).json({ message: 'Invalid credentials' });
    }
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/influ
