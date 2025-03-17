I'll show you how to implement a secure authentication system in Python using Flask with hashed passwords and MFA (Multi-Factor Authentication) using an authenticator app (like Google Authenticator). Here's a practical implementation:
python
from flask import Flask, request, jsonify, session
from werkzeug.security import generate_password_hash, check_password_hash
import pyotp
import sqlite3
import secrets
import time

app = Flask(__name__)
app.secret_key = secrets.token_hex(16)  # Secure random secret key

# Database setup
def init_db():
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS users 
                (id INTEGER PRIMARY KEY, 
                 email TEXT UNIQUE, 
                 password_hash TEXT, 
                 mfa_secret TEXT)''')
    conn.commit()
    conn.close()

# User registration
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    if not email or not password:
        return jsonify({'error': 'Email and password required'}), 400
    
    # Generate password hash
    password_hash = generate_password_hash(password)
    
    # Generate MFA secret
    mfa_secret = pyotp.random_base32()
    
    try:
        conn = sqlite3.connect('users.db')
        c = conn.cursor()
        c.execute('INSERT INTO users (email, password_hash, mfa_secret) VALUES (?, ?, ?)',
                 (email, password_hash, mfa_secret))
        conn.commit()
        
        # Return MFA secret for user to set up in authenticator app
        totp = pyotp.TOTP(mfa_secret)
        qr_uri = totp.provisioning_uri(email, issuer_name="YourApp")
        
        return jsonify({
            'message': 'Registration successful',
            'mfa_qr_uri': qr_uri  # User scans this with authenticator app
        })
    except sqlite3.IntegrityError:
        return jsonify({'error': 'Email already exists'}), 400
    finally:
        conn.close()

# User login
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    mfa_token = data.get('mfa_token')
    
    if not all([email, password, mfa_token]):
        return jsonify({'error': 'All fields required'}), 400
    
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute('SELECT password_hash, mfa_secret FROM users WHERE email = ?', (email,))
    user = c.fetchone()
    conn.close()
    
    if not user:
        return jsonify({'error': 'Invalid credentials'}), 401
    
    password_hash, mfa_secret = user
    
    # Verify password
    if not check_password_hash(password_hash, password):
        return jsonify({'error': 'Invalid credentials'}), 401
    
    # Verify MFA token
    totp = pyotp.TOTP(mfa_secret)
    if not totp.verify(mfa_token):
        return jsonify({'error': 'Invalid MFA token'}), 401
    
    # Successful login
    session['user_email'] = email
    return jsonify({'message': 'Login successful'})

# Protected route example
@app.route('/protected', methods=['GET'])
def protected():
    if 'user_email' not in session:
        return jsonify({'error': 'Unauthorized'}), 401
    return jsonify({'message': f"Welcome {session['user_email']}"})

# Logout
@app.route('/logout', methods=['POST'])
def logout():
    session.pop('user_email', None)
    return jsonify({'message': 'Logged out'})

if __name__ == '__main__':
    init_db()
    app.run(debug=True, ssl_context='adhoc')  # Enable HTTPS in development
Key security features in this implementation:
Password Hashing:
Uses werkzeug.security for secure password hashing (PBKDF2 by default)
Never stores plain-text passwords
MFA Implementation:
Uses pyotp for Time-based One-Time Passwords (TOTP)
Generates a unique secret key for each user
Compatible with Google Authenticator and similar apps
Session Management:
Uses Flask's secure session handling
Random secret key generated on startup
To use this in practice, you'll need to:
Install required packages:
bash
pip install flask werkzeug pyotp sqlite3
Frontend requirements:
Registration form (email, password)
Display QR code for MFA setup (using mfa_qr_uri)
Login form (email, password, MFA token field)
Additional security recommendations:
python
# Add these to enhance security

# Rate limiting
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(app=app, key_func=get_remote_address)
@app.route('/login', methods=['POST'])
@limiter.limit("5 per minute")  # Limit login attempts
def login():
    # ... existing login code ...

# Secure session cookies
app.config.update(
    SESSION_COOKIE_SECURE=True,  # Only send over HTTPS
    SESSION_COOKIE_HTTPONLY=True,  # Prevent JavaScript access
    SESSION_COOKIE_SAMESITE='Lax',  # CSRF protection
)

# Input validation
from email_validator import validate_email, EmailNotValidError
def validate_input(email, password):
    try:
        valid = validate_email(email)
        email = valid.email
        if len(password) < 8:
            raise ValueError("Password must be at least 8 characters")
        return email, password
    except (EmailNotValidError, ValueError) as e:
        return jsonify({'error': str(e)}), 400
Additional considerations:
Use environment variables for sensitive configurations
Implement proper error logging
Add password complexity requirements
Use a production WSGI server (e.g., Gunicorn) instead of Flask's development server
Configure proper HTTPS with a valid certificate in production
Add account lockout after failed attempts
Implement password reset functionality securely
This implementation protects against:
Email/password breaches (through hashing)
Credential stuffing (through MFA)
Basic session hijacking (through secure cookies)
Simple brute force attacks (with rate limiting)
Would you like me to elaborate on any specific part of this implementation?
