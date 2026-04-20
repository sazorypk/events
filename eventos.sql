-- Prender el motor de eventos
SET GLOBAL event_scheduler = ON;

-- Tabla reportes monitoreo
CREATE TABLE registro_monitoreo (
    id_registro INT AUTO_INCREMENT PRIMARY KEY,
    tipo_evento VARCHAR(100),
    fecha_ejecucion DATETIME,
    mensaje TEXT
);

DELIMITER //

-- 1. Generar facturas mensuales
-- corre el 1 de cada mes y le crea factura a los contratos activos
CREATE EVENT EVT_GenerarFacturasMensuales
ON SCHEDULE EVERY 1 MONTH STARTS '2024-05-01 00:00:00'
DO
BEGIN
    INSERT INTO facturas (id_cliente, periodo_facturado, fecha_emision, fecha_vencimiento, cargos_fijos, total_pagar, estado_pago, forma_pago)
    SELECT 
        id_cliente, 
        DATE_FORMAT(CURDATE(), '%Y-%m'), -- Formato Año-Mes
        CURDATE(), 
        DATE_ADD(CURDATE(), INTERVAL 15 DAY), -- Dan 15 días para pagar
        monto_mensual, 
        monto_mensual, 
        'Pendiente', 
        'Pendiente'
    FROM contratos 
    WHERE estado_actual = 'Activo';
END //

-- 2. Verificar calidad de servicio
-- Corre cada semana. Actualiza la fecha de verificación de internet y deja un registro
CREATE EVENT EVT_VerificarCalidadServicio
ON SCHEDULE EVERY 1 WEEK
DO
BEGIN
    -- sistema revisa los parámetros
    UPDATE servicios_internet_fijo SET fecha_ultima_verificacion = NOW();
    
    -- Guardamos en tabla de monitoreo
    INSERT INTO registro_monitoreo (tipo_evento, fecha_ejecucion, mensaje)
    VALUES ('Calidad de Servicio', NOW(), 'Revisión semanal de parámetros de internet completada.');
END //

-- 3. Actualizar tarifas planes
-- Corre cada año. Le sube el 5% al valor de los planes
CREATE EVENT EVT_ActualizarTarifasPlanes
ON SCHEDULE EVERY 1 YEAR
DO
BEGIN
    UPDATE plan_de_servicio
    SET tarifa_mensual = tarifa_mensual * 1.05
    WHERE estado = 'Vigente';
END //

-- 4. Verificar vencimiento contratos
-- Corre todos los días. Si la fecha de inicio + los meses de duración ya pasó, lo cambia a Cancelado.
CREATE EVENT EVT_VerificarVencimientoContratos
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    UPDATE contratos
    SET estado_actual = 'Cancelado'
    WHERE DATE_ADD(fecha_inicio, INTERVAL duracion_meses MONTH) < CURDATE()
    AND estado_actual = 'Activo';
END //

-- 5. Monitorear rendimiento red
-- Corre todos los días para revisar antenas. Deja un registro si hay alguna en mantenimiento.
CREATE EVENT EVT_MonitorearRendimientoRed
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    DECLARE antenas_caidas INT;
    
    -- Contamos cuántas antenas están en mantenimiento o inactivas
    SELECT COUNT(*) INTO antenas_caidas FROM antenas_equipos_de_red WHERE estado_operativo != 'Activo';
    
    -- Guardamos el reporte
    INSERT INTO registro_monitoreo (tipo_evento, fecha_ejecucion, mensaje)
    VALUES ('Rendimiento Red', NOW(), CONCAT('Revisión diaria de red. Nodos con problemas o mantenimiento: ', antenas_caidas));
END //

DELIMITER ;

SHOW EVENTS;