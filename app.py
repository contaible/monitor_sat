from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import json
import os
import logging
from datetime import datetime
import base64
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import xml.etree.ElementTree as ET
import re

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Permite CORS para desarrollo

# Configuración (en producción usar variables de entorno)
class Config:
    FINKOK_API_URL = "https://api.finkok.com/v3/cfdi33/status"
    FINKOK_USERNAME = os.getenv('FINKOK_USERNAME', 'tu_usuario_finkok')
    FINKOK_PASSWORD = os.getenv('FINKOK_PASSWORD', 'tu_password_finkok')
    CERT_PATH = os.getenv('CERT_PATH', 'certificados/cert.cer')
    KEY_PATH = os.getenv('KEY_PATH', 'certificados/key.key')
    DEBUG = os.getenv('DEBUG', 'True').lower() == 'true'

config = Config()

class SATMonitor:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'User-Agent': 'Monitor-SAT/1.0'
        })
    
    def validar_rfc(self, rfc):
        """Valida formato básico del RFC"""
        if not rfc:
            return False
        
        rfc = rfc.strip()
        
        # RFC debe tener 12 o 13 caracteres
        if len(rfc) < 12 or len(rfc) > 13:
            return False
        
        # Validación básica de formato
        # Personas morales: 12 caracteres (3 letras + 6 dígitos + 3 caracteres)
        # Personas físicas: 13 caracteres (4 letras + 6 dígitos + 3 caracteres)
        
        if len(rfc) == 12:
            # Persona moral: ABC123456789
            pattern = r'^[A-Z&Ñ]{3}[0-9]{6}[A-Z0-9]{3}$'
        else:
            # Persona física: ABCD123456789
            pattern = r'^[A-Z&Ñ]{4}[0-9]{6}[A-Z0-9]{3}$'
        
        return bool(re.match(pattern, rfc))
    
    def cargar_certificado(self):
        """Carga el certificado y llave privada"""
        try:
            # En un entorno real, estos archivos deben estar seguros
            with open(config.CERT_PATH, 'rb') as cert_file:
                cert_data = cert_file.read()
            
            with open(config.KEY_PATH, 'rb') as key_file:
                key_data = key_file.read()
            
            return base64.b64encode(cert_data).decode(), base64.b64encode(key_data).decode()
        except FileNotFoundError:
            logger.error("Archivos de certificado no encontrados")
            return None, None
        except Exception as e:
            logger.error(f"Error cargando certificados: {str(e)}")
            return None, None
    
    def consultar_finkok(self, rfc):
        """Consulta la API de Finkok para obtener el estatus SAT"""
        try:
            cert_b64, key_b64 = self.cargar_certificado()
            if not cert_b64 or not key_b64:
                return {"error": "Error cargando certificados"}
            
            payload = {
                "username": config.FINKOK_USERNAME,
                "password": config.FINKOK_PASSWORD,
                "rfc": rfc,
                "certificate": cert_b64,
                "private_key": key_b64
            }
            
            response = self.session.post(
                config.FINKOK_API_URL,
                json=payload,
                timeout=30
            )
            
            response.raise_for_status()
            return response.json()
            
        except requests.exceptions.RequestException as e:
            logger.error(f"Error en petición a Finkok: {str(e)}")
            return {"error": f"Error de conexión: {str(e)}"}
        except Exception as e:
            logger.error(f"Error inesperado: {str(e)}")
            return {"error": f"Error interno: {str(e)}"}
    
    def procesar_respuesta_sat(self, data_sat, rfc):
        """Procesa la respuesta del SAT y estructura los datos"""
        try:
            # Simular datos reales (en producción vendría del SAT)
            if "error" in data_sat:
                return data_sat
            
            # Estructura de respuesta estándar
            respuesta = {
                "rfc": rfc,
                "timestamp": datetime.now().isoformat(),
                "status": "success",
                "datos": {
                    "pendientes": data_sat.get("pendientes", 0),
                    "vencidas": data_sat.get("vencidas", 0),
                    "discrepancias": data_sat.get("discrepancias", 0),
                    "total_facturas": data_sat.get("total_facturas", 0),
                    "monto_total": data_sat.get("monto_total", 0.0)
                },
                "alertas": self.generar_alertas(data_sat)
            }
            
            return respuesta
            
        except Exception as e:
            logger.error(f"Error procesando respuesta SAT: {str(e)}")
            return {"error": f"Error procesando datos: {str(e)}"}
    
    def generar_alertas(self, data):
        """Genera alertas basadas en los datos del SAT"""
        alertas = []
        
        pendientes = data.get("pendientes", 0)
        vencidas = data.get("vencidas", 0)
        discrepancias = data.get("discrepancias", 0)
        
        if vencidas > 0:
            alertas.append({
                "tipo": "critico",
                "mensaje": f"Tienes {vencidas} facturas vencidas que requieren atención inmediata"
            })
        
        if pendientes > 10:
            alertas.append({
                "tipo": "advertencia",
                "mensaje": f"Tienes {pendientes} facturas pendientes de procesamiento"
            })
        
        if discrepancias > 0:
            alertas.append({
                "tipo": "atencion",
                "mensaje": f"Se encontraron {discrepancias} discrepancias en tus facturas"
            })
        
        return alertas

# Instancia del monitor
monitor = SATMonitor()

@app.route('/', methods=['GET'])
def health_check():
    """Endpoint de verificación de salud"""
    return jsonify({
        "service": "Monitor SAT Backend",
        "status": "running",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    })

@app.route('/consultar_sat', methods=['POST'])
def consultar_sat():
    """Endpoint principal para consultar el estatus SAT"""
    try:
        # Verificar Content-Type
        if not request.is_json:
            return jsonify({'error': 'Content-Type debe ser application/json'}), 400
        
        # Validar datos de entrada
        if not request.json:
            return jsonify({'error': 'Se requiere JSON en el cuerpo de la petición'}), 400
        
        rfc = request.json.get('rfc')
        if not rfc:
            return jsonify({'error': 'Se requiere el campo "rfc"'}), 400
            
        rfc = rfc.strip().upper()
        
        if not monitor.validar_rfc(rfc):
            return jsonify({'error': 'RFC inválido. Formato: ABCD123456789 (13 caracteres) o ABC123456789 (12 caracteres)'}), 400
        
        logger.info(f"Consultando SAT para RFC: {rfc}")
        
        # Consultar API de Finkok
        data_sat = monitor.consultar_finkok(rfc)
        
        # Procesar respuesta
        respuesta = monitor.procesar_respuesta_sat(data_sat, rfc)
        
        # Determinar código de estado HTTP
        if "error" in respuesta:
            return jsonify(respuesta), 500
        
        return jsonify(respuesta), 200
        
    except Exception as e:
        logger.error(f"Error en consultar_sat: {str(e)}")
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/consultar_multiple', methods=['POST'])
def consultar_multiple():
    """Endpoint para consultar múltiples RFCs"""
    try:
        if not request.json or 'rfcs' not in request.json:
            return jsonify({'error': 'Se requiere una lista de RFCs'}), 400
        
        rfcs = request.json['rfcs']
        if not isinstance(rfcs, list) or len(rfcs) == 0:
            return jsonify({'error': 'La lista de RFCs no puede estar vacía'}), 400
        
        if len(rfcs) > 10:  # Límite de seguridad
            return jsonify({'error': 'Máximo 10 RFCs por consulta'}), 400
        
        resultados = []
        
        for rfc in rfcs:
            if monitor.validar_rfc(rfc):
                data_sat = monitor.consultar_finkok(rfc)
                resultado = monitor.procesar_respuesta_sat(data_sat, rfc)
                resultados.append(resultado)
            else:
                resultados.append({
                    'rfc': rfc,
                    'error': 'RFC inválido'
                })
        
        return jsonify({
            'resultados': resultados,
            'total_consultados': len(resultados),
            'timestamp': datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error en consultar_multiple: {str(e)}")
        return jsonify({'error': 'Error interno del servidor'}), 500

@app.route('/estadisticas', methods=['GET'])
def estadisticas_generales():
    """Endpoint para obtener estadísticas generales del sistema"""
    # En producción, estos datos vendrían de una base de datos
    stats = {
        "consultas_hoy": 150,
        "rfcs_activos": 25,
        "alertas_criticas": 3,
        "uptime": "99.9%",
        "ultima_actualizacion": datetime.now().isoformat()
    }
    
    return jsonify(stats), 200

@app.errorhandler(400)
def bad_request(error):
    return jsonify({'error': 'Petición incorrecta'}), 400

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Endpoint no encontrado'}), 404

@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({'error': 'Método no permitido'}), 405

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Error interno: {str(error)}")
    return jsonify({'error': 'Error interno del servidor'}), 500

# Manejador para JSON malformado
from werkzeug.exceptions import BadRequest

@app.before_request
def validate_json():
    if request.endpoint and request.method == 'POST':
        if request.content_type and 'application/json' in request.content_type:
            try:
                request.get_json(force=True)
            except BadRequest:
                return jsonify({'error': 'JSON malformado'}), 400

if __name__ == '__main__':
    # Crear directorio para certificados si no existe
    os.makedirs('certificados', exist_ok=True)
    
    logger.info("Iniciando Monitor SAT Backend...")
    logger.info(f"Debug mode: {config.DEBUG}")
    
    app.run(
        debug=config.DEBUG,
        host='0.0.0.0',
        port=int(os.getenv('PORT', 5000))
    )