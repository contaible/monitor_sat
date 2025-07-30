# 📚 Monitor SAT Backend - Ejemplos de Uso

## 🔍 Endpoints Disponibles

### 1. Health Check
**GET** `/`

Verifica que el servicio esté funcionando correctamente.

```bash
curl -X GET https://tu-dominio.com/
```

**Respuesta:**
```json
{
  "service": "Monitor SAT Backend",
  "status": "running",
  "version": "1.0.0",
  "timestamp": "2025-07-28T10:30:00.000Z"
}
```

---

### 2. Consultar SAT (Individual)
**POST** `/consultar_sat`

Consulta el estatus SAT para un RFC específico.

#### Ejemplo con cURL:
```bash
curl -X POST https://tu-dominio.com/consultar_sat \
  -H "Content-Type: application/json" \
  -d '{
    "rfc": "XEXX010101XXX"
  }'
```

#### Ejemplo con Python:
```python
import requests

url = "https://tu-dominio.com/consultar_sat"
payload = {"rfc": "XEXX010101XXX"}

response = requests.post(url, json=payload)
data = response.json()
print(data)
```

#### Ejemplo con JavaScript:
```javascript
const consultarSAT = async (rfc) => {
  try {
    const response = await fetch('https://tu-dominio.com/consultar_sat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ rfc: rfc })
    });
    
    const data = await response.json();
    console.log(data);
    return data;
  } catch (error) {
    console.error('Error:', error);
  }
};

// Uso
consultarSAT('XEXX010101XXX');
```

**Respuesta exitosa:**
```json
{
  "rfc": "XEXX010101XXX",
  "timestamp": "2025-07-28T10:30:00.000Z",
  "status": "success",
  "datos": {
    "pendientes": 5,
    "vencidas": 2,
    "discrepancias": 1,
    "total_facturas": 150,
    "monto_total": 125000.50
  },
  "alertas": [
    {
      "tipo": "critico",
      "mensaje": "Tienes 2 facturas vencidas que requieren atención inmediata"
    },
    {
      "tipo": "atencion",
      "mensaje": "Se encontraron 1 discrepancias en tus facturas"
    }
  ]
}
```

**Respuesta con error:**
```json
{
  "error": "RFC inválido"
}
```

---

### 3. Consultar Múltiples RFCs
**POST** `/consultar_multiple`

Consulta el estatus SAT para varios RFCs de una vez (máximo 10).

#### Ejemplo:
```bash
curl -X POST https://tu-dominio.com/consultar_multiple \
  -H "Content-Type: application/json" \
  -d '{
    "rfcs": ["XEXX010101XXX", "YEYY020202YYY", "ZEZZ030303ZZZ"]
  }'
```

**Respuesta:**
```json
{
  "resultados": [
    {
      "rfc": "XEXX010101XXX",
      "timestamp": "2025-07-28T10:30:00.000Z",
      "status": "success",
      "datos": {
        "pendientes": 5,
        "vencidas": 2,
        "discrepancias": 1,
        "total_facturas": 150,
        "monto_total": 125000.50
      },
      "alertas": []
    },
    {
      "rfc": "YEYY020202YYY",
      "error": "RFC inválido"
    }
  ],
  "total_consultados": 2,
  "timestamp": "2025-07-28T10:30:00.000Z"
}
```

---

### 4. Estadísticas Generales
**GET** `/estadisticas`

Obtiene estadísticas generales del sistema.

```bash
curl -X GET https://tu-dominio.com/estadisticas
```

**Respuesta:**
```json
{
  "consultas_hoy": 150,
  "rfcs_activos": 25,
  "alertas_criticas": 3,
  "uptime": "99.9%",
  "ultima_actualizacion": "2025-07-28T10:30:00.000Z"
}
```

---

## 🛠️ Códigos de Estado HTTP

| Código | Descripción | Caso de Uso |
|--------|-------------|-------------|
| 200 | OK | Consulta exitosa |
| 400 | Bad Request | RFC inválido, JSON malformado |
| 404 | Not Found | Endpoint no existe |
| 405 | Method Not Allowed | Método HTTP incorrecto |
| 500 | Internal Server Error | Error del servidor, problemas con SAT/Finkok |

---

## 📱 Integración con Frontend

### React.js
```jsx
import React, { useState } from 'react';

const SATMonitor = () => {
  const [rfc, setRfc] = useState('');
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);

  const consultarSAT = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/consultar_sat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rfc })
      });
      const result = await response.json();
      setData(result);
    } catch (error) {
      console.error('Error:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <input 
        value={rfc} 
        onChange={(e) => setRfc(e.target.value)}
        placeholder="Ingresa RFC"
      />
      <button onClick={consultarSAT} disabled={loading}>
        {loading ? 'Consultando...' : 'Consultar SAT'}
      </button>
      {data && (
        <div>
          <h3>Resultados para {data.rfc}</h3>
          <p>Pendientes: {data.datos?.pendientes}</p>
          <p>Vencidas: {data.datos?.vencidas}</p>
          <p>Discrepancias: {data.datos?.discrepancias}</p>
        </div>
      )}
    </div>
  );
};

export default SATMonitor;
```

### Vue.js
```vue
<template>
  <div>
    <input v-model="rfc" placeholder="Ingresa RFC" />
    <button @click="consultarSAT" :disabled="loading">
      {{ loading ? 'Consultando...' : 'Consultar SAT' }}
    </button>
    <div v-if="data">
      <h3>Resultados para {{ data.rfc }}</h3>
      <p>Pendientes: {{ data.datos?.pendientes }}</p>
      <p>Vencidas: {{ data.datos?.vencidas }}</p>
      <p>Discrepancias: {{ data.datos?.discrepancias }}</p>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      rfc: '',
      data: null,
      loading: false
    };
  },
  methods: {
    async consultarSAT() {
      this.loading = true;
      try {
        const response = await fetch('/api/consultar_sat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ rfc: this.rfc })
        });
        this.data = await response.json();
      } catch (error) {
        console.error('Error:', error);
      } finally {
        this.loading = false;
      }
    }
  }
};
</script>
```

---

## 🤖 Integración con Bots

### Bot de Telegram
```python
import asyncio
import aiohttp
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters

async def consultar_sat_command(update: Update, context):
    rfc = ' '.join(context.args)
    
    if not rfc:
        await update.message.reply_text("Uso: /consultar RFC")
        return
    
    async with aiohttp.ClientSession() as session:
        async with session.post(
            'https://tu-dominio.com/consultar_sat',
            json={'rfc': rfc}
        ) as response:
            data = await response.json()
            
            if 'error' in data:
                message = f"❌ Error: {data['error']}"
            else:
                datos = data['datos']
                message = f"""
📊 Estatus SAT para {rfc}:
• Pendientes: {datos['pendientes']}
• Vencidas: {datos['vencidas']}
• Discrepancias: {datos['discrepancias']}
• Total facturas: {datos['total_facturas']}
• Monto total: ${datos['monto_total']:,.2f}
                """
            
            await update.message.reply_text(message)

# Configurar bot
app = Application.builder().token("TU_BOT_TOKEN").build()
app.add_handler(CommandHandler("consultar", consultar_sat_command))
```

### Webhook para WhatsApp Business
```python
@app.route('/webhook/whatsapp', methods=['POST'])
def webhook_whatsapp():
    data = request.json
    
    # Procesar mensaje de WhatsApp
    message = data.get('message', {})
    text = message.get('text', '').strip()
    phone = data.get('from')
    
    if text.startswith('/consultar '):
        rfc = text.replace('/consultar ', '').strip()
        
        # Consultar SAT
        result = monitor.consultar_finkok(rfc)
        response_data = monitor.procesar_respuesta_sat(result, rfc)
        
        # Formatear respuesta para WhatsApp
        if 'error' in response_data:
            reply = f"❌ Error: {response_data['error']}"
        else:
            datos = response_data['datos']
            reply = f"""
📊 *Estatus SAT*
RFC: {rfc}
• Pendientes: {datos['pendientes']}
• Vencidas: {datos['vencidas']}
• Discrepancias: {datos['discrepancias']}
            """
        
        # Enviar respuesta via WhatsApp Business API
        send_whatsapp_message(phone, reply)
    
    return jsonify({'status': 'ok'})
```

---

## 📊 Monitoreo con Grafana

### Métricas Personalizadas
```python
from prometheus_client import Counter, Histogram, generate_latest

# Métricas
consultas_total = Counter('sat_consultas_total', 'Total consultas SAT')
tiempo_respuesta = Histogram('sat_tiempo_respuesta_segundos', 'Tiempo respuesta consultas')

@app.route('/metrics')
def metrics():
    return generate_latest()

# En tus endpoints
@tiempo_respuesta.time()
def consultar_sat():
    consultas_total.inc()
    # Tu código aquí
```

---

## 🔧 Configuración Avanzada

### Variables de Entorno Completas
```bash
# .env
DEBUG=False
PORT=5000
WORKERS=4

# Finkok
FINKOK_USERNAME=tu_usuario
FINKOK_PASSWORD=tu_password
FINKOK_API_URL=https://api.finkok.com/v3/cfdi33/status

# Certificados
CERT_PATH=/path/to/cert.cer
KEY_PATH=/path/to/key.key

# Base de datos (opcional)
DATABASE_URL=postgresql://user:pass@localhost/monitor_sat

# Cache
REDIS_URL=redis://localhost:6379/0

# Logs
LOG_LEVEL=INFO
LOG_FILE=/var/log/monitor-sat/app.log

# Seguridad
SECRET_KEY=tu_clave_secreta_muy_larga
RATE_LIMIT=100

# AWS (opcional)
AWS_REGION=us-west-2
AWS_SECRET_NAME=monitor-sat/credentials
```

### Docker Compose para Desarrollo
```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "5000:5000"
    environment:
      - DEBUG=True
      - DATABASE_URL=postgresql://postgres:password@db:5432/monitor_sat
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - ./certificados:/app/certificados
    depends_on:
      - db
      - redis

  db:
    image: postgres:13
    environment:
      POSTGRES_DB: monitor_sat
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine

volumes:
  postgres_data:
```

---

¡Con estos ejemplos y configuraciones tendrás un backend completamente funcional para tu Monitor SAT! 🚀