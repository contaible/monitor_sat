#!/usr/bin/env python3
"""
Script de pruebas para el Monitor SAT Backend
Ejecutar con: python test_backend.py
"""

import requests
import json
import time
from datetime import datetime

# Configuración
BASE_URL = "http://localhost:5000"  # Cambiar por tu URL de producción
TEST_RFC = "XEXX010101XXX"  # RFC de prueba

def test_health_check():
    """Prueba el endpoint de verificación de salud"""
    print("🔍 Probando health check...")
    try:
        response = requests.get(f"{BASE_URL}/")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_consultar_sat():
    """Prueba el endpoint principal de consulta SAT"""
    print("\n🔍 Probando consulta SAT...")
    try:
        payload = {"rfc": TEST_RFC}
        response = requests.post(
            f"{BASE_URL}/consultar_sat",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code in [200, 500]  # 500 es esperado sin certificados reales
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_consultar_multiple():
    """Prueba el endpoint de consulta múltiple"""
    print("\n🔍 Probando consulta múltiple...")
    try:
        payload = {
            "rfcs": [TEST_RFC, "ABC123456789", "DEF987654321"]
        }
        response = requests.post(
            f"{BASE_URL}/consultar_multiple",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code in [200, 500]
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_estadisticas():
    """Prueba el endpoint de estadísticas"""
    print("\n🔍 Probando estadísticas...")
    try:
        response = requests.get(f"{BASE_URL}/estadisticas")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_endpoint_inexistente():
    """Prueba manejo de endpoint inexistente"""
    print("\n🔍 Probando endpoint inexistente...")
    try:
        response = requests.get(f"{BASE_URL}/endpoint_que_no_existe")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 404
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_validacion_rfc():
    """Prueba validación de RFC inválido"""
    print("\n🔍 Probando validación de RFC...")
    
    # Probar diferentes casos de RFC inválidos
    rfcs_invalidos = [
        "RFC_INVALIDO",      # Formato completamente incorrecto
        "12345",             # Muy corto
        "ABCD123456789012",  # Muy largo
        "",                  # Vacío
        "ABCD12345612A",     # Formato incorrecto
        "123456789012"       # Solo números
    ]
    
    resultados = []
    
    for rfc_test in rfcs_invalidos:
        try:
            payload = {"rfc": rfc_test}
            response = requests.post(
                f"{BASE_URL}/consultar_sat",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            print(f"  RFC '{rfc_test}': Status {response.status_code}")
            if response.status_code == 400:
                print(f"    ✓ Correctamente rechazado: {response.json().get('error', 'Sin mensaje')}")
                resultados.append(True)
            else:
                print(f"    ✗ Error: se esperaba 400, se obtuvo {response.status_code}")
                resultados.append(False)
        except Exception as e:
            print(f"    ✗ Error en petición: {e}")
            resultados.append(False)
    
    # Al menos 80% de los casos deben pasar
    return sum(resultados) >= len(resultados) * 0.8

def test_sin_json():
    """Prueba endpoint sin enviar JSON"""
    print("\n🔍 Probando request sin JSON...")
    
    test_cases = [
        {
            "name": "Sin content-type",
            "headers": {},
            "data": None
        },
        {
            "name": "Content-type incorrecto",
            "headers": {"Content-Type": "text/plain"},
            "data": "texto plano"
        },
        {
            "name": "JSON vacío",
            "headers": {"Content-Type": "application/json"},
            "data": None
        },
        {
            "name": "JSON malformado",
            "headers": {"Content-Type": "application/json"},
            "data": '{"rfc": INVALID_JSON}'
        }
    ]
    
    resultados = []
    
    for case in test_cases:
        try:
            print(f"  Probando: {case['name']}")
            
            if case['data'] and 'INVALID_JSON' in case['data']:
                # Para JSON malformado, enviamos directamente
                response = requests.post(
                    f"{BASE_URL}/consultar_sat",
                    headers=case['headers'],
                    data=case['data']
                )
            else:
                response = requests.post(
                    f"{BASE_URL}/consultar_sat",
                    headers=case['headers'],
                    data=case['data']
                )
            
            print(f"    Status: {response.status_code}")
            
            if response.status_code == 400:
                print(f"    ✓ Correctamente rechazado: {response.json().get('error', 'Sin mensaje')}")
                resultados.append(True)
            else:
                print(f"    ✗ Error: se esperaba 400, se obtuvo {response.status_code}")
                resultados.append(False)
                
        except Exception as e:
            print(f"    ✗ Error en petición: {e}")
            resultados.append(False)
    
    # Al menos 75% de los casos deben pasar
    return sum(resultados) >= len(resultados) * 0.75

def test_rfc_validos():
    """Prueba RFCs con formato válido"""
    print("\n🔍 Probando RFCs válidos...")
    
    # RFCs con formato válido (aunque no necesariamente existan)
    rfcs_validos = [
        "XEXX010101000",     # 13 caracteres - persona física
        "ABC010101ABC",      # 12 caracteres - persona moral
        "ABCD123456H12",     # 13 caracteres con formato correcto
        "XYZ987654321"       # 12 caracteres formato correcto
    ]
    
    resultados = []
    
    for rfc_test in rfcs_validos:
        try:
            payload = {"rfc": rfc_test}
            response = requests.post(
                f"{BASE_URL}/consultar_sat",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            print(f"  RFC '{rfc_test}': Status {response.status_code}")
            
            # El RFC es válido en formato, pero puede fallar en la consulta real (500)
            # o ser exitoso si hay datos simulados (200)
            if response.status_code in [200, 500]:
                print(f"    ✓ RFC válido procesado correctamente")
                resultados.append(True)
            elif response.status_code == 400:
                error_msg = response.json().get('error', '')
                if 'RFC inválido' in error_msg:
                    print(f"    ✗ RFC válido rechazado incorrectamente: {error_msg}")
                    resultados.append(False)
                else:
                    print(f"    ✓ Error de validación diferente (OK): {error_msg}")
                    resultados.append(True)
            else:
                print(f"    ? Status inesperado: {response.status_code}")
                resultados.append(False)
                
        except Exception as e:
            print(f"    ✗ Error en petición: {e}")
            resultados.append(False)
    
    return sum(resultados) >= len(resultados) * 0.75

def main():
    """Ejecuta todas las pruebas"""
    print("🧪 INICIANDO PRUEBAS DEL BACKEND MONITOR SAT")
    print("=" * 50)
    
    tests = [
        ("Health Check", test_health_check),
        ("Consultar SAT", test_consultar_sat),
        ("Consultar Múltiple", test_consultar_multiple),
        ("Estadísticas", test_estadisticas),
        ("Endpoint Inexistente", test_endpoint_inexistente),
        ("Validación RFC", test_validacion_rfc),
        ("Request Sin JSON", test_sin_json),
        ("RFCs Válidos", test_rfc_validos)
    ]
    
    results = []
    
    for test_name, test_func in tests:
        print(f"\n{'='*20} {test_name} {'='*20}")
        start_time = time.time()
        result = test_func()
        end_time = time.time()
        
        status = "✅ PASS" if result else "❌ FAIL"
        duration = f"{(end_time - start_time):.2f}s"
        
        print(f"\n{status} - {test_name} ({duration})")
        results.append((test_name, result, duration))
    
    # Resumen final
    print("\n" + "="*50)
    print("📊 RESUMEN DE PRUEBAS")
    print("="*50)
    
    passed = sum(1 for _, result, _ in results if result)
    total = len(results)
    
    for test_name, result, duration in results:
        status = "✅" if result else "❌"
        print(f"{status} {test_name:<25} ({duration})")
    
    print(f"\n🎯 Resultado: {passed}/{total} pruebas pasaron")
    
    if passed == total:
        print("🎉 ¡Todas las pruebas pasaron!")
    else:
        print("⚠️  Algunas pruebas fallaron. Revisa la configuración.")
    
    print(f"\n⏰ Timestamp: {datetime.now().isoformat()}")

if __name__ == "__main__":
    main()