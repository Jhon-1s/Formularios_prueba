# Sistema de Formularios Dinámicos (Form Builder)

Este repositorio contiene la infraestructura backend y la aplicación móvil nativa del proyecto de estadía profesional **Form Builder**. El sistema está diseñado para la creación, gestión y captura automatizada de formularios dinámicos con soporte de lógica condicional, evidencias multimedia (fotos, firmas digitales).

---

## Stack Tecnológico Seleccionado
* **Backend (API Core):** Node.js con JavaScript y Express.js
* **Capa de Consultas:** GraphQL utilizando **Apollo Server**
* **Base de Datos:** MySQL (Diseño, administración y control mediante **MySQL Workbench**)
* **Seguridad:** Autenticación basada en el estándar **JSON Web Tokens (JWT)** y encriptación de credenciales con **Bcryptjs**
* **Aplicación Cliente:** **Flutter** (Dart) para el despliegue de operadores en campo

---

## Tabla de Control de Fases y Cronograma de Actividades

A continuación, se detalla el plan maestro de desarrollo estructurado en fases de ingeniería y entregables semanales detallados para el control administrativo de la estadía:

| Fase / Etapa | Sem | Fecha Reunión | Actividades Dev 1 (Backend / API) | Actividades Dev 2 (App Móvil / Integración) | Entregable de Avance Global | Estado Actual |
| :--- | :---: | :---: | :--- | :--- | :--- | :---: |
| **Fase 1: Arquitectura Base y Datos** | **S1** | 07 May 2026 | Configuración backend, modelo de datos inicial, endpoints base. | Inicialización proyecto Flutter, arquitectura de carpetas y layouts base. | Entornos listos y servidor corriendo. | **🟢 Finalizado** |
| | **S2** | 14 May 2026 | API de autenticación JWT y roles (ADMIN/OPERADOR). | Desarrollo login en Flutter + persistencia de token en sesión local. | Login funcional + app móvil capaz de iniciar sesión segura. | **🟢 Finalizado** |
| | **S3** | 21 May 2026 | Endpoints de gestión de empresas y subida de logos. | Maquetación de Dashboard y menú de navegación en Flutter. | Endpoints de empresas + home en móvil. | **🟢 Finalizado** |
| | **S4** | 28 May 2026 | Endpoints para almacenar respuestas desde la app móvil. | Módulo de sincronización en Flutter: descarga y lista de formularios. | **Base de Datos & Arquitectura Base:** Backend guarda formularios; app los descarga y lista. | **🟢 Finalizado** |
| **Fase 2: Motor Dinámico** | **S5** | 04 Jun 2026 | Endpoints para recibir archivos pesados (imágenes, firmas). | Componentes visuales en Flutter (texto, selectores, fecha). | Endpoints listos para cualquier tipo de pregunta. | **🟢 Finalizado** |
| | **S6** | 11 Jun 2026 | API de geolocalización (GPS adjunto al envío). | Motor de renderizado dinámico en Flutter. | App dibuja formularios desde JSON del backend. | **🟢 Finalizado** |
| | **S7** | 18 Jun 2026 | Servicio automático de generación de PDF (Puppeteer/PDFKit). | Evaluador de lógica condicional en tiempo real (mostrar/ocultar). | **API Core:** Formularios con lógica condicional en móvil. | 🟢 Finalizado |
| **Fase 3: Captura de Evidencias** | **S8** | 25 Jun 2026 | Endpoints de consulta histórica y filtros. | Integración de cámara en app móvil. | **App Flutter Funcional (Fase 1):** App captura fotos y las envía al backend. | ⏳ Sin Iniciar |
| | **S9** | 02 Jul 2026 | Pruebas de estrés y auditoría de seguridad JWT. | Implementación de firma táctil (Signature Pad). | App captura firma y envía encuestas completas. | ⏳ Sin Iniciar |
| | **S10** | 09 Jul 2026 | Documentación técnica de API (Swagger/Postman). | Integración GPS en Flutter (coordenadas). | **Motor Móvil & Evidencias:** Respuestas con fotos, firma y GPS en BD. | ⏳ Sin Iniciar |
| **Fase 4: Reportes y Cierre** | **S11** | 16 Jul 2026 | Optimización del servicio de PDF y corrección de bugs. | Pruebas de rendimiento en baja conectividad. | **Servicio de PDF:** PDF generado automáticamente con branding. | ⏳ Sin Iniciar |
| | **S12** | 23 Jul 2026 | API de reportería completa (filtros, históricos). | Optimización de app móvil (caché, fluidez). | **API Reportería:** Endpoints listos para frontend web. | ⏳ Sin Iniciar |
| | **S13** | 30 Jul 2026 | Pruebas E2E (backend ↔ app) y estabilización. | Pruebas de compatibilidad (resoluciones, Android/iOS). | **Sistema Integrado:** Sistema congelado y estable. | ⏳ Sin Iniciar |
| | **S14** | 06 Ago 2026 | Documentación final de API (Swagger/Postman). | Redacción manual de usuario app. | **Doc. Técnica:** Documentación API + manual de usuario. | ⏳ Sin Iniciar |
| | **S15** | 13 Ago 2026 | Preparación del backend y scripts de BD para entrega. | Empaquetado final .apk y código móvil listo. | **Manual de Usuario y Código Fuente:** Entrega final del ecosistema completo. | ⏳ Sin Iniciar |

---

## Estructura del Proyecto

## Documentación  