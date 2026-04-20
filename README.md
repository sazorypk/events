# events
TelecomSys - Módulo de Automatización y Eventos
Descripción general del proyecto
Este proyecto es una extensión del sistema de gestión de bases de datos TelecomSys, enfocado específicamente en la automatización de procesos operativos. Utilizando el programador de eventos (Event Scheduler) de MariaDB, se implementó un sistema de tareas en segundo plano que ejecuta operaciones críticas de la empresa de telecomunicaciones de forma autónoma.

El objetivo de este módulo es reducir la carga manual del personal, asegurando que la facturación, el monitoreo de la red, la revisión de contratos y la actualización de tarifas se realicen con precisión y en las fechas exactas requeridas, manteniendo además una bitácora (registro_monitoreo) para auditorías del sistema.

Estructura de los módulos implementados
Para este entregable, la lógica de automatización se estructuró a través de cinco eventos principales que cubren las áreas clave del negocio:

Módulo de Facturación (EVT_GenerarFacturasMensuales): Evento mensual que genera automáticamente los cobros para todos los clientes que tienen un contrato en estado "Activo".

Módulo de Soporte y Red:

EVT_VerificarCalidadServicio: Tarea semanal que actualiza las fechas de revisión de los nodos de internet y deja constancia en la bitácora.

EVT_MonitorearRendimientoRed: Tarea diaria que cuenta cuántas antenas están fallando o en mantenimiento, alertando a través de la tabla de registros.

Módulo de Gestión Comercial:

EVT_ActualizarTarifasPlanes: Evento anual que aplica un incremento automático del 5% a las tarifas de los planes vigentes.

EVT_VerificarVencimientoContratos: Revisión diaria que detecta qué contratos ya cumplieron su tiempo de duración y los pasa automáticamente a estado "Cancelado".

Instrucciones de uso
Para ejecutar y probar estos eventos en su entorno local de MariaDB, siga cuidadosamente estos pasos:

Requisito indispensable: Antes de correr cualquier código de eventos, debe encender el motor de tareas en segundo plano de la base de datos. Ejecute el siguiente comando en su consola SQL:
SET GLOBAL event_scheduler = ON;

Asegúrese de estar posicionado sobre la base de datos correcta (USE telecomunicaciones_telecomsys;).

Copie y ejecute todo el bloque de código que se encuentra en la sección Script de la base de datos (esto creará la tabla de bitácora y los 5 eventos).

Para verificar que se crearon: Ejecute el comando SHOW EVENTS;. Verá una lista con los 5 eventos y su estado activo.

Para revisar que el monitoreo funciona: Debido a que hay eventos diarios y semanales, puede simular el paso del tiempo o esperar a que se ejecuten y luego consultar la bitácora con: SELECT * FROM registro_monitoreo;

Script de la base de datos
SQL
-- 1. Habilitar el motor de eventos
SET GLOBAL event_scheduler = ON;

-- 2. Crear tabla de bitácora para registrar acciones automáticas
CREATE TABLE registro_monitoreo (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    tipo_evento VARCHAR(100),
    fecha_ejecucion DATETIME,
    mensaje TEXT
);

DELIMITER //

-- 3. Evento 1: Generar facturas mensuales
CREATE EVENT EVT_GenerarFacturasMensuales
ON SCHEDULE EVERY 1 MONTH STARTS '2024-05-01 00:00:00'
DO
BEGIN
    INSERT INTO facturas (id_cliente, periodo_facturado, fecha_emision, fecha_vencimiento, cargos_fijos, total_pagar, estado_pago, forma_pago)
    SELECT 
        id_cliente, 
        DATE_FORMAT(CURDATE(), '%Y-%m'), 
        CURDATE(), 
        DATE_ADD(CURDATE(), INTERVAL 15 DAY), 
        monto_mensual, 
        monto_mensual, 
        'Pendiente', 
        'Pendiente'
    FROM contratos 
    WHERE estado_actual = 'Activo';
END //

-- 4. Evento 2: Verificar calidad de servicio (Semanal)
CREATE EVENT EVT_VerificarCalidadServicio
ON SCHEDULE EVERY 1 WEEK
DO
BEGIN
    UPDATE servicios_internet_fijo SET fecha_ultima_verificacion = NOW();
    
    INSERT INTO registro_monitoreo (tipo_evento, fecha_ejecucion, mensaje)
    VALUES ('Calidad de Servicio', NOW(), 'Revisión semanal de parámetros de internet completada.');
END //

-- 5. Evento 3: Actualizar tarifas planes (Anual)
CREATE EVENT EVT_ActualizarTarifasPlanes
ON SCHEDULE EVERY 1 YEAR
DO
BEGIN
    UPDATE plan_de_servicio
    SET tarifa_mensual = tarifa_mensual * 1.05
    WHERE estado = 'Vigente';
END //

-- 6. Evento 4: Verificar vencimiento contratos (Diario)
CREATE EVENT EVT_VerificarVencimientoContratos
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    UPDATE contratos
    SET estado_actual = 'Cancelado'
    WHERE DATE_ADD(fecha_inicio, INTERVAL duracion_meses MONTH) < CURDATE()
    AND estado_actual = 'Activo';
END //

-- 7. Evento 5: Monitorear rendimiento red (Diario)
CREATE EVENT EVT_MonitorearRendimientoRed
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    DECLARE antenas_caidas INT;
    
    SELECT COUNT(*) INTO antenas_caidas FROM antenas_equipos_de_red WHERE estado_operativo != 'Activo';
    
    INSERT INTO registro_monitoreo (tipo_evento, fecha_ejecucion, mensaje)
    VALUES ('Rendimiento Red', NOW(), CONCAT('Revisión diaria de red. Nodos con problemas o mantenimiento: ', antenas_caidas));
END //

DELIMITER ;
