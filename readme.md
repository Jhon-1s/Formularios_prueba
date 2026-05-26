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

| Fase / Etapa | Semana | Fecha Fin | Entregable Backend / API | Entregable App Móvil / Flutter | Estado Actual |
| :--- | :---: | :---: | :--- | :--- | :---: |
| **Fase 1: Arquitectura Base y Datos** | **S1** | 07 May 2026 | Inicialización de Node.js, dependencias listas y pool de conexión con MySQL Workbench. | Creación del proyecto limpio en Flutter, arquitectura de carpetas y layouts base. | ✅ Finalizado |
| | **S2** | 14 May 2026 | API de autenticación JWT, hashing de contraseñas con bcrypt y control de roles (`ADMIN`/`OPERADOR`). | Diseño de la pantalla de Login e integración del almacenamiento del Token. | ⏳ En Proceso |
| | **S3** | 21 May 2026 | Desarrollo del CRUD corporativo de Empresas y lógica para almacenamiento de logotipos comerciales. | Desarrollo del módulo visual de perfil y lectura de datos de la empresa. | ❌ Sin iniciar |
| **Fase 2: Motor de Formularios** | **S4** | 28 May 2026 | Modelado relacional y API para control de estructuras de cuestionarios, bloques y secciones. | Maquetación de vistas contenedoras de encuestas y lógica de navegación. | ❌ Sin iniciar |
| | **S5** | 04 Jun 2026 | Endpoints y Resolvers del constructor de preguntas y taxonomías (Texto, Selección, etc.). | Diseño de inputs dinámicos interactivos y adaptables según el tipo de dato. | ❌ Sin iniciar |
| | **S6** | 11 Jun 2026 | Arquitectura lógica del motor de reglas condicionales en base de datos (Mostrar/Ocultar). | Implementación de widgets reactivos condicionales en tiempo real. | ❌ Sin iniciar |
| | **S7** | 18 Jun 2026 | Optimizaciones de consultas y resolvers indexados para formularios dinámicos masivos. | Intérprete JSON completamente funcional; renderizado dinámico completo. | ❌ Sin iniciar |
| **Fase 3: Captura de Evidencias** | **S8** | 25 Jun 2026 | Endpoints de consulta histórica de formularios, ordenamientos complejos y filtros. | Enlace de hardware nativo para la captura y serialización de fotografías en campo. | ❌ Sin iniciar |
| | **S9** | 02 Jul 2026 | Pruebas de estrés y rendimiento del servidor de consultas; auditoría de seguridad JWT. | Implementación técnica de lienzo de firma táctil digital (Signature Pad Canvas). | ❌ Sin iniciar |
| | **S10** | 09 Jul 2026 | Documentación técnica detallada de la API GraphQL (Esquemas de consultas, mutations y resolvers). | Extracción automatizada de coordenadas geográficas mediante hardware GPS. | ❌ Sin iniciar |
| **Fase 4: Reportes y Cierre** | **S11** | 16 Jul 2026 | Microservicio asíncrono para el mapeo y compilación de respuestas en plantillas de archivos. | Pruebas de rendimiento del cliente móvil y sincronización en baja conectividad. | ❌ Sin iniciar |
| | **S12** | 23 Jul 2026 | API de reportería documental completa para la descarga y exportación de archivos PDF corporativos. | Optimización de memoria caché en el dispositivo celular y fluidez de interfaz. | ❌ Sin iniciar |
| | **S13** | 30 Jul 2026 | Pruebas de integración de extremo a extremo (E2E Backend ↔ App) y parches de incidencias. | Pruebas de compatibilidad multiplataforma (Múltiples pantallas y resoluciones). | ❌ Sin iniciar |
| | **S14** | 06 Ago 2026 | Congelamiento definitivo de código, auditoría final del sistema y preparación de servidores. | Empaquetado final de binarios de distribución móvil (Compilación de APK/AAB). | ❌ Sin iniciar |
| | **S15** | 13 Ago 2026 | Cierre administrativo de estadía profesional, firmas de liberación y entrega de plataforma. | Presentación y entrega final del ecosistema tecnológico completo ante asesores. | ❌ Sin iniciar |

---

## Estructura del Proyecto

## Documentación