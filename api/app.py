from flask import Flask, request, jsonify
import os
import logging
from datetime import datetime

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for load balancer"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    }), 200

@app.route('/api/webhook', methods=['POST'])
def webhook():
    """Webhook endpoint to receive third-party communications"""
    try:
        data = request.get_json()
        logger.info(f"Received webhook: {data}")
        
        return jsonify({
            'status': 'ok',
            'message': 'Webhook received successfully'
        }), 200
        
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': 'Internal server error'
        }), 500

@app.route('/', methods=['GET'])
def root():
    """Root endpoint"""
    return jsonify({
        'message': 'DevOps Interview API',
        'endpoints': {
            '/health': 'Health check',
            '/api/webhook': 'Webhook receiver'
        }
    }), 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=False)