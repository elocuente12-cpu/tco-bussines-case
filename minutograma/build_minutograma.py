#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera el minutograma (runbook) de la migracion/DR de InteliSrcPA en formato .xlsx.

Tres escenarios (una hoja cada uno) + portada:
  1. Cutover  On-Premise1 -> AWS   (migracion inicial, sacar OnPrem1)
  2. Failover AWS -> On-Premise2    (contingencia / DR)
  3. Failback On-Premise2 -> AWS    (retorno controlado)

Formato tomado de "Plan de Trabajo Preventa.xlsx" (header azul #4985E8, Arial)
combinado con la estructura de fases del Change Request ServiceNow de la imagen:
  Pre Implementation -> Implementation -> Go/No-Go -> Post Implementation -> Backout
"""

from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

OUT = "/Users/javier.sepulveda/projects/experian/tco-bussines-case/minutograma/Minutograma_Migracion_DR_InteliSrcPA.xlsx"

# ---------------------------------------------------------------- estilos ----
HEADER_FILL = PatternFill("solid", fgColor="4985E8")   # azul como el Plan de Trabajo
HEADER_FONT = Font(name="Arial", bold=True, color="FFFFFF", size=10)
TITLE_FONT  = Font(name="Arial", bold=True, color="1F3864", size=16)
SUB_FONT    = Font(name="Arial", bold=False, color="333333", size=10)
CELL_FONT   = Font(name="Arial", size=9)
PHASE_FONT  = Font(name="Arial", bold=True, color="FFFFFF", size=10)

# color por fase (fase = fila-grupo)
PHASE_FILLS = {
    "Pre Implementation":       PatternFill("solid", fgColor="2E75B6"),
    "Implementation":           PatternFill("solid", fgColor="1F6F43"),
    "Go/No Go Implementation":  PatternFill("solid", fgColor="BF8F00"),
    "Post Implementation":      PatternFill("solid", fgColor="7030A0"),
    "Backout Task":             PatternFill("solid", fgColor="C00000"),
}
ALT_FILL = PatternFill("solid", fgColor="F2F6FC")       # zebra
thin = Side(style="thin", color="D9D9D9")
BORDER = Border(left=thin, right=thin, top=thin, bottom=thin)
WRAP_TOP = Alignment(wrap_text=True, vertical="top")
CENTER   = Alignment(horizontal="center", vertical="center", wrap_text=True)

COLUMNS = [
    ("Number",           14),
    ("Sequence",         10),
    ("Phase",            22),
    ("Short description",40),
    ("Detalle tecnico / Comando",             56),
    ("Componente / Recurso",                  26),
    ("Responsable (Assignment group)",        26),
    ("Estado",           12),
    ("Duracion (min)",   13),
    ("Ventana / Planned start",               22),
    ("Validacion / Criterio de exito",        44),
    ("Rollback",         40),
]

ASSIGN_DEFAULT = "SP LATAM Panama Infrastructure"
STATE_DEFAULT  = "Draft"

# 8 sitios IIS / apps (de terraform.tfvars alb_apps + iis_sites)
APPS = [
    ("app1", "mobile.apc.com.pa",        "TuIntelidat\\intelidat_App_wsv5"),
    ("app1", "tuintelidat.com",          "TuIntelidat\\TuIntelidat"),
    ("app1", "apcexperian.com",          "TuIntelidat\\Apcexperian"),
    ("app2", "online.intelidat.com",     "InteliSRC\\SRC20"),
    ("app3", "webfolder.intelidat.com",  "WFApcExperian\\WebFolderPortal"),
    ("app4", "webservices.apcexperian.com","CrediWeb\\WS\\wwwroot"),
    ("app4", "webservices.apc.com.pa",   "CrediWeb\\WS\\wwwroot"),
    ("app5", "api.apcexperian.com",      "API_PA\\wwwroot"),
    ("app5", "apiprodpa.experian.local", "API_PA\\wwwroot"),
    ("app6", "www.miexperian.cl",        "ECS_Chile\\ECSConsumers"),
    ("app7", "apps.apcexperian.com",     "apps_pa\\PortalApps"),
    ("app7", "dashboard.apcexperian.com","apps_pa\\MercadoDashboard"),
]

# bases DMS (8) de dms.tf
DMS_DBS = ["apcexperian", "WebFolderPortal", "AppDb", "APC_GI",
           "TuIntelidat", "DBECSConsumers", "PortalAppsDB", "SRC20"]


def make_sheet(wb, title, chg, subtitle, rows):
    """rows: lista de (phase, short_desc, detalle, componente, dur, validacion, rollback)"""
    ws = wb.create_sheet(title=title)

    # Titulo
    ncol = len(COLUMNS)
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=ncol)
    c = ws.cell(row=1, column=1, value=subtitle)
    c.font = TITLE_FONT
    c.alignment = Alignment(vertical="center")
    ws.row_dimensions[1].height = 26

    ws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=ncol)
    c = ws.cell(row=2, column=1,
                value=("Change request: %s   |   Assignment group: %s   |   "
                       "Estado inicial: %s   |   Aplicacion: InteliSrcPA (AppID 22272) "
                       "- eec-aws-us-eits-intelisrcpa-prd") % (chg, ASSIGN_DEFAULT, STATE_DEFAULT))
    c.font = SUB_FONT
    ws.row_dimensions[2].height = 16

    # Header (fila 3)
    hrow = 3
    for i, (name, width) in enumerate(COLUMNS, start=1):
        cell = ws.cell(row=hrow, column=i, value=name)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = CENTER
        cell.border = BORDER
        ws.column_dimensions[get_column_letter(i)].width = width
    ws.row_dimensions[hrow].height = 30
    ws.freeze_panes = "A4"

    # Filas de datos, agrupadas por fase
    r = hrow + 1
    seq = 0
    task_no = 1
    current_phase = None
    phase_order = ["Pre Implementation", "Implementation", "Go/No Go Implementation",
                   "Post Implementation", "Backout Task"]

    # ordenar por fase manteniendo orden de insercion dentro de fase
    rows_sorted = sorted(rows, key=lambda x: phase_order.index(x[0]))

    zebra = False
    for (phase, short, detalle, comp, dur, valid, rollback) in rows_sorted:
        if phase != current_phase:
            # fila separadora de fase
            ws.merge_cells(start_row=r, start_column=1, end_row=r, end_column=ncol)
            pc = ws.cell(row=r, column=1, value="FASE: %s" % phase)
            pc.fill = PHASE_FILLS[phase]
            pc.font = PHASE_FONT
            pc.alignment = Alignment(vertical="center", indent=1)
            ws.row_dimensions[r].height = 20
            r += 1
            current_phase = phase
            zebra = False

        seq += 10
        number = "IMPTASK-%02d" % task_no
        task_no += 1
        values = [number, seq, phase, short, detalle, comp, ASSIGN_DEFAULT,
                  STATE_DEFAULT, dur, "", valid, rollback]
        for i, v in enumerate(values, start=1):
            cell = ws.cell(row=r, column=i, value=v)
            cell.font = CELL_FONT
            cell.border = BORDER
            if i in (1, 2, 8, 9):
                cell.alignment = CENTER
            else:
                cell.alignment = WRAP_TOP
            if zebra:
                cell.fill = ALT_FILL
        ws.row_dimensions[r].height = 30
        r += 1
        zebra = not zebra

    return ws


# =====================================================================
#  ESCENARIO 1 : CUTOVER  On-Premise1  ->  AWS
# =====================================================================
cutover = [
    # ---- Pre Implementation ----
    ("Pre Implementation", "Congelamiento de cambios (change freeze) en OnPrem1",
     "Notificar freeze de despliegues/DDL en OnPrem1. Bloquear pipelines de release hacia los sitios IIS y las BD SQL Server on-premise.",
     "Gobierno / OnPrem1", 30,
     "Confirmacion escrita de freeze; no hay jobs de despliegue activos.",
     "No aplica (actividad administrativa)."),
    ("Pre Implementation", "Validar salud de la plataforma AWS destino",
     "Verificar ASG (7 apps) healthy en TG del ALB, RDS produccion (multiaz1) y procesos (standalone1) disponibles, FSx online, DMS replication instance 'poc' available.",
     "AWS (ALB/ASG/RDS/FSx/DMS)", 30,
     "Todos los target groups healthy; RDS status=available; FSx=AVAILABLE; DMS=available.",
     "No aplica."),
    ("Pre Implementation", "Verificar carga inicial + CDC de datos (DMS OnPrem1->AWS)",
     "Confirmar que las 8 tareas DMS (apcexperian, WebFolderPortal, AppDb, APC_GI, TuIntelidat, DBECSConsumers, PortalAppsDB, SRC20) estan en estado 'Load complete, replication ongoing' con latencia CDC baja.",
     "DMS (8 tasks) / RDS produccion", 45,
     "CDCLatencySource y CDCLatencyTarget < 5s en las 8 tareas; sin errores en CloudWatch.",
     "No aplica (aun no se corta OnPrem1)."),
    ("Pre Implementation", "Verificar sincronizacion DFS-R (contenido IIS) hacia FSx",
     "Validar backlog de DFS-R = 0 entre file servers OnPrem1 y FSx para los directorios de cada sitio (TuIntelidat, InteliSRC, WFApcExperian, CrediWeb, API_PA, ECS_Chile, apps_pa).",
     "FSx / DFS-R", 45,
     "dfsrdiag Backlog = 0 en todos los replication groups; contenido consistente.",
     "No aplica."),
    ("Pre Implementation", "Preparar Imperva (DNS) para el cutover",
     "Validar en Imperva que existen los sites de las 8 apps, con origin AWS (ALB interno via conectividad) y health checks configurados. Bajar TTL de DNS a 60s.",
     "Imperva (WAF/DNS/Failover)", 30,
     "Sites Imperva configurados; TTL=60s propagado; health checks OK contra AWS.",
     "Revertir TTL al valor previo."),

    # ---- Implementation ----
    ("Implementation", "Detener escritura en OnPrem1 (quiesce aplicaciones)",
     "Detener/parar app pools IIS y servicios de escritura en OnPrem1 para evitar doble escritura. Dejar OnPrem1 en modo solo-lectura o apagado de sitios.",
     "OnPrem1 (IIS)", 20,
     "Sitios OnPrem1 fuera de servicio; sin nuevas transacciones.",
     "Reiniciar app pools OnPrem1."),
    ("Implementation", "Cortar CDC y hacer cutover de datos a RDS (por base)",
     "Esperar que DMS aplique el ultimo LSN pendiente por base; detener las 8 tareas CDC OnPrem1->AWS de forma ordenada tras confirmar latencia 0.",
     "DMS / RDS produccion", 40,
     "Latencia CDC=0 antes de detener; conteos de control (rowcounts) OnPrem1 vs RDS coinciden por base.",
     "Reactivar tareas CDC OnPrem1->AWS."),
    ("Implementation", "Cerrar convergencia DFS-R y fijar FSx como autoritativo",
     "Confirmar ultimo sync DFS-R OnPrem1->FSx con backlog 0; a partir de aqui FSx es el origen autoritativo del contenido de los sitios en AWS.",
     "FSx / DFS-R", 30,
     "Backlog 0; hash/spot-check de archivos clave por sitio OK.",
     "Re-habilitar sync desde OnPrem1."),
    ("Implementation", "Publicar apps en AWS via ASG/IIS",
     "Confirmar que las instancias del ASG (montan FSx en Z:, IIS configurado por sitio) responden 200 en el health check '/' del ALB para las 8 apps.",
     "ASG / ALB / IIS", 30,
     "TG healthy en las 8 apps; respuesta 200 en cada host_header desde el ALB.",
     "N/A (se corrige en Go/No-Go)."),
    ("Implementation", "Redireccionar trafico en Imperva OnPrem1 -> AWS",
     "En Imperva, apuntar el origin/DNS de los 8 sites a AWS y ejecutar el switch de trafico. Validar por host_header: mobile.apc.com.pa, tuintelidat.com, apcexperian.com, online.intelidat.com, webfolder.intelidat.com, webservices.apcexperian.com, webservices.apc.com.pa, api.apcexperian.com, apps.apcexperian.com, www.miexperian.cl.",
     "Imperva / DNS", 40,
     "Trafico entrante llega a AWS; curl/pruebas por cada FQDN retornan contenido correcto.",
     "Revertir origin/DNS de Imperva a OnPrem1."),

    # ---- Go/No Go ----
    ("Go/No Go Implementation", "Pruebas funcionales por aplicacion (8 apps)",
     "Ejecutar smoke tests de negocio en cada sitio (login, consulta, transaccion representativa) validando datos servidos desde RDS + contenido desde FSx.",
     "QA / Aplicaciones", 60,
     "Checklist funcional OK en las 8 apps; sin errores 5xx; datos correctos.",
     "Decision de Backout si falla critico."),
    ("Go/No Go Implementation", "Decision Go / No-Go",
     "Reunion de decision con stakeholders (infra, apps, negocio). Evaluar resultados de pruebas y metricas. Registrar decision.",
     "Gobierno / CAB", 20,
     "Decision Go registrada en el CHG; o activar Backout.",
     "Si No-Go: ejecutar tareas de Backout."),

    # ---- Post Implementation ----
    ("Post Implementation", "Activar DMS AWS -> OnPrem2 (nuevo DR)",
     "Habilitar/validar las tareas DMS unidireccionales AWS(RDS multiaz1) -> OnPrem2 para las 8 bases, dejando OnPrem2 como replica de contingencia.",
     "DMS / OnPrem2 (SQL cluster)", 40,
     "Tareas DMS AWS->OnPrem2 replicando; latencia CDC estable.",
     "Detener tareas si generan impacto."),
    ("Post Implementation", "Configurar DFS-R bidireccional FSx <-> OnPrem2",
     "Validar replication groups DFS-R entre FSx (AWS) y los DFS de OnPrem2 para los directorios de los sitios; confirmar convergencia bidireccional.",
     "FSx / DFS-R / OnPrem2", 40,
     "Backlog 0 en ambos sentidos; contenido consistente FSx<->OnPrem2.",
     "Aislar OnPrem2 del RG si hay conflicto."),
    ("Post Implementation", "Desmantelar/aislar OnPrem1 y restaurar TTL",
     "Sacar OnPrem1 de la ecuacion: apagar sitios IIS y detener replicaciones remanentes desde OnPrem1. Restaurar TTL DNS a valor estandar. Actualizar CMDB.",
     "OnPrem1 / Imperva / CMDB", 30,
     "OnPrem1 sin trafico ni replicacion; CMDB actualizado; TTL restaurado.",
     "Reactivar OnPrem1 (solo si Backout global)."),
    ("Post Implementation", "Monitoreo hipercare",
     "Vigilar CloudWatch (ALB 5xx, ASG CPU/target tracking, RDS, FSx), DMS y DFS-R durante ventana de estabilizacion.",
     "Operaciones / AWS", 60,
     "Sin alarmas criticas durante la ventana de hipercare.",
     "Escalar segun severidad."),

    # ---- Backout ----
    ("Backout Task", "Revertir trafico a OnPrem1 en Imperva",
     "Reapuntar los 8 sites de Imperva de vuelta a OnPrem1 (origin/DNS). Validar que OnPrem1 vuelve a servir.",
     "Imperva / OnPrem1", 30,
     "Trafico servido por OnPrem1; pruebas por FQDN OK.",
     "N/A (es el rollback)."),
    ("Backout Task", "Reactivar OnPrem1 (datos y contenido)",
     "Re-habilitar app pools IIS de OnPrem1 y reactivar CDC/DFS-R hacia OnPrem1 si fue necesario detenerlos. Verificar consistencia.",
     "OnPrem1 (IIS/SQL/DFS)", 40,
     "OnPrem1 operativo y consistente; sitios respondiendo.",
     "N/A."),
    ("Backout Task", "Cierre de Backout y comunicacion",
     "Registrar en el CHG el resultado del backout, notificar a stakeholders y programar nueva ventana.",
     "Gobierno", 20,
     "CHG actualizado; comunicacion enviada.",
     "N/A."),
]

# =====================================================================
#  ESCENARIO 2 : FAILOVER  AWS  ->  On-Premise2  (contingencia / DR)
# =====================================================================
failover = [
    # ---- Pre Implementation ----
    ("Pre Implementation", "Declarar contingencia y convocar equipo DR",
     "Declaracion formal de evento de contingencia sobre AWS. Convocar roles de infra, BD, apps y Imperva. Abrir puente de comunicacion.",
     "Gobierno / DR", 15,
     "Contingencia declarada; equipo convocado; puente activo.",
     "N/A (activacion)."),
    ("Pre Implementation", "Evaluar estado de AWS y de OnPrem2",
     "Determinar alcance de la falla en AWS. Verificar salud de OnPrem2: cluster SQL Server, servidores IIS por app y DFS locales.",
     "AWS / OnPrem2", 30,
     "Diagnostico claro; OnPrem2 listo para asumir carga.",
     "N/A."),
    ("Pre Implementation", "Verificar frescura de datos en OnPrem2",
     "Confirmar hasta que LSN llego la replica DMS AWS->OnPrem2 por base (8 DBs) y calcular RPO/perdida potencial.",
     "DMS / OnPrem2 (SQL cluster)", 30,
     "RPO conocido y aceptado por negocio; brecha de datos documentada.",
     "N/A."),
    ("Pre Implementation", "Verificar contenido en DFS de OnPrem2",
     "Confirmar convergencia DFS-R hacia OnPrem2 para los directorios de los sitios (backlog conocido).",
     "DFS-R / OnPrem2", 30,
     "Contenido de sitios disponible y consistente en OnPrem2.",
     "N/A."),

    # ---- Implementation ----
    ("Implementation", "Detener replicacion AWS -> OnPrem2 (promover OnPrem2)",
     "Detener las 8 tareas DMS AWS->OnPrem2 para promover el cluster SQL de OnPrem2 como base de escritura (evitar conflictos).",
     "DMS / OnPrem2 (SQL cluster)", 30,
     "Tareas detenidas; SQL OnPrem2 en modo escritura.",
     "Reanudar DMS AWS->OnPrem2."),
    ("Implementation", "Ajustar DFS-R para escritura en OnPrem2",
     "Asegurar que los servidores IIS de OnPrem2 sirven el contenido desde su DFS local; gestionar direccion de replicacion para evitar conflictos durante la contingencia.",
     "DFS-R / OnPrem2 (IIS)", 30,
     "Sitios OnPrem2 leen contenido correcto; sin conflictos DFS.",
     "Restaurar config DFS-R previa."),
    ("Implementation", "Levantar/validar sitios IIS por app en OnPrem2",
     "Confirmar que el servidor IIS de cada app en OnPrem2 sirve su sitio (1 servidor por app), apuntando a SQL OnPrem2 y DFS local.",
     "OnPrem2 (IIS)", 40,
     "Los 8 sitios responden localmente en OnPrem2 (200 OK).",
     "Reiniciar/ajustar app pools OnPrem2."),
    ("Implementation", "Failover de trafico en Imperva AWS -> OnPrem2",
     "En Imperva ejecutar el failover: reapuntar origin/DNS de los 8 sites hacia OnPrem2. Imperva realiza el switch de las aplicaciones a internet.",
     "Imperva / DNS", 30,
     "Trafico entrante llega a OnPrem2; pruebas por FQDN OK.",
     "Reapuntar Imperva de vuelta a AWS."),

    # ---- Go/No Go ----
    ("Go/No Go Implementation", "Pruebas funcionales en OnPrem2 (8 apps)",
     "Smoke tests de negocio por sitio validando datos desde SQL OnPrem2 y contenido desde DFS local.",
     "QA / OnPrem2", 45,
     "Checklist OK en las 8 apps; sin errores criticos.",
     "Decidir Backout si falla."),
    ("Go/No Go Implementation", "Decision Go / No-Go de failover",
     "Confirmar operacion estable en OnPrem2 y aceptar RPO. Registrar decision.",
     "Gobierno / CAB", 15,
     "Failover confirmado; o revertir a AWS.",
     "Ejecutar Backout."),

    # ---- Post Implementation ----
    ("Post Implementation", "Estabilizar y monitorear OnPrem2",
     "Vigilar rendimiento del cluster SQL, servidores IIS y DFS en OnPrem2 durante la contingencia.",
     "Operaciones / OnPrem2", 60,
     "Operacion estable; sin incidentes criticos.",
     "Escalar segun severidad."),
    ("Post Implementation", "Preparar reversa de replicacion para failback",
     "Cuando AWS se recupere, planificar la captura de cambios ocurridos en OnPrem2 para el failback (delta a re-sincronizar hacia AWS).",
     "DMS / DFS-R", 40,
     "Estrategia de delta OnPrem2->AWS definida y validada.",
     "N/A."),
    ("Post Implementation", "Comunicacion de estado de contingencia",
     "Notificar a negocio y stakeholders el estado de operacion en DR y el plan de failback.",
     "Gobierno", 15,
     "Comunicacion enviada; expectativas alineadas.",
     "N/A."),

    # ---- Backout ----
    ("Backout Task", "Revertir failover (volver a AWS) si aplica",
     "Si el failover no es viable o AWS se recupera de inmediato, reapuntar Imperva a AWS y reanudar DMS AWS->OnPrem2.",
     "Imperva / DMS / AWS", 30,
     "Trafico de vuelta en AWS; replicacion reanudada.",
     "N/A (es el rollback)."),
    ("Backout Task", "Reconciliar datos si hubo escritura en OnPrem2",
     "Si hubo transacciones en OnPrem2, reconciliar/re-aplicar hacia AWS antes de restablecer el sentido normal de replicacion.",
     "DBA / DMS", 45,
     "Datos reconciliados; sin perdida ni duplicados.",
     "N/A."),
]

# =====================================================================
#  ESCENARIO 3 : FAILBACK  On-Premise2  ->  AWS  (retorno controlado)
# =====================================================================
failback = [
    # ---- Pre Implementation ----
    ("Pre Implementation", "Confirmar recuperacion total de AWS",
     "Verificar que la plataforma AWS esta sana: ASG (7 apps), ALB, RDS multiaz1/standalone1, FSx y DMS operativos.",
     "AWS", 30,
     "Todos los componentes AWS available/healthy.",
     "Posponer failback."),
    ("Pre Implementation", "Programar ventana de failback controlado",
     "Acordar ventana de mantenimiento con negocio (failback es planificado, no automatico). Notificar a usuarios.",
     "Gobierno / Negocio", 20,
     "Ventana aprobada y comunicada.",
     "Reprogramar."),
    ("Pre Implementation", "Re-sincronizar datos OnPrem2 -> AWS (delta)",
     "Configurar/ejecutar la replicacion inversa temporal (DMS o backup/restore) para llevar a AWS los cambios ocurridos en OnPrem2 durante la contingencia (8 bases).",
     "DMS / DBA", 60,
     "RDS AWS al dia con OnPrem2; latencia CDC ~0; rowcounts coinciden.",
     "Mantener operacion en OnPrem2."),
    ("Pre Implementation", "Re-sincronizar contenido DFS OnPrem2 -> FSx",
     "Asegurar que DFS-R propago a FSx los cambios de contenido hechos en OnPrem2 (backlog 0).",
     "DFS-R / FSx", 45,
     "Backlog 0; contenido FSx consistente con OnPrem2.",
     "Mantener OnPrem2 como origen."),

    # ---- Implementation ----
    ("Implementation", "Quiesce de escritura en OnPrem2",
     "Detener escritura en los sitios IIS de OnPrem2 y aplicar ultimo delta pendiente hacia AWS.",
     "OnPrem2 (IIS/SQL)", 20,
     "Sin nuevas transacciones en OnPrem2; delta final aplicado.",
     "Reactivar OnPrem2."),
    ("Implementation", "Restablecer sentido normal de replicacion",
     "Reconfigurar DMS a su sentido de produccion (AWS RDS -> OnPrem2) y DFS-R bidireccional FSx<->OnPrem2 con FSx como autoritativo.",
     "DMS / DFS-R", 40,
     "Replicacion en sentido produccion; OnPrem2 vuelve a rol DR.",
     "Revertir a sentido OnPrem2->AWS."),
    ("Implementation", "Validar publicacion en AWS (ASG/IIS/ALB)",
     "Confirmar TG healthy y respuesta 200 por host_header en las 8 apps servidas desde AWS.",
     "ASG / ALB / IIS", 30,
     "Las 8 apps healthy en AWS.",
     "Corregir antes de switch."),
    ("Implementation", "Failback de trafico en Imperva OnPrem2 -> AWS",
     "Reapuntar origin/DNS de los 8 sites de Imperva hacia AWS. Ejecutar el switch controlado.",
     "Imperva / DNS", 30,
     "Trafico servido por AWS; pruebas por FQDN OK.",
     "Reapuntar a OnPrem2."),

    # ---- Go/No Go ----
    ("Go/No Go Implementation", "Pruebas funcionales post-failback (8 apps)",
     "Smoke tests por sitio validando datos desde RDS AWS y contenido desde FSx.",
     "QA / Aplicaciones", 45,
     "Checklist OK en las 8 apps.",
     "Backout si falla critico."),
    ("Go/No Go Implementation", "Decision Go / No-Go de failback",
     "Confirmar operacion estable en AWS con OnPrem2 nuevamente como DR. Registrar decision.",
     "Gobierno / CAB", 15,
     "Failback confirmado; o revertir a OnPrem2.",
     "Ejecutar Backout."),

    # ---- Post Implementation ----
    ("Post Implementation", "Restaurar OnPrem2 como DR de contingencia",
     "Confirmar que OnPrem2 queda como replica DR: DMS AWS->OnPrem2 activo y DFS-R bidireccional convergido.",
     "DMS / DFS-R / OnPrem2", 40,
     "OnPrem2 en rol DR; replicaciones estables.",
     "N/A."),
    ("Post Implementation", "Monitoreo hipercare post-failback",
     "Vigilar CloudWatch, DMS y DFS-R durante la ventana de estabilizacion.",
     "Operaciones / AWS", 60,
     "Sin alarmas criticas.",
     "Escalar segun severidad."),
    ("Post Implementation", "Cierre del failback y CMDB",
     "Actualizar CMDB/CHG, documentar lecciones aprendidas y restaurar TTL DNS estandar.",
     "Gobierno / CMDB", 20,
     "CHG cerrado; documentacion completa.",
     "N/A."),

    # ---- Backout ----
    ("Backout Task", "Revertir failback a OnPrem2",
     "Si el failback presenta fallas, reapuntar Imperva a OnPrem2 y volver a promover OnPrem2 como origen de escritura.",
     "Imperva / OnPrem2", 30,
     "Trafico de vuelta en OnPrem2; operacion estable.",
     "N/A (es el rollback)."),
    ("Backout Task", "Reconciliar y reprogramar",
     "Reconciliar cualquier delta y reprogramar nueva ventana de failback.",
     "DBA / Gobierno", 30,
     "Datos consistentes; nueva ventana agendada.",
     "N/A."),
]


def cover_sheet(wb):
    ws = wb.create_sheet(title="Portada", index=0)
    ws.sheet_view.showGridLines = False
    ws.column_dimensions["A"].width = 4
    ws.column_dimensions["B"].width = 30
    ws.column_dimensions["C"].width = 90

    ws.merge_cells("B2:C2")
    c = ws.cell(row=2, column=2, value="Minutograma - Migracion y DR")
    c.font = Font(name="Arial", bold=True, size=20, color="1F3864")
    ws.merge_cells("B3:C3")
    c = ws.cell(row=3, column=2, value="Aplicacion InteliSrcPA  |  eec-aws-us-eits-intelisrcpa-prd  |  AppID 22272")
    c.font = Font(name="Arial", size=11, color="333333")

    info = [
        ("Owner", "Fernando Hidalgo"),
        ("Assignment group", ASSIGN_DEFAULT),
        ("CostString", "1741.PA.135.601000"),
        ("Region AWS (principal)", "us-east-1 (N. Virginia)"),
        ("DR alterno", "On-Premise 2 (cluster SQL Server + IIS por app + DFS)"),
        ("On-Premise 1", "Origen a migrar (se saca de la ecuacion tras el cutover)"),
    ]
    r = 5
    for k, v in info:
        ws.cell(row=r, column=2, value=k).font = Font(name="Arial", bold=True, size=10)
        ws.cell(row=r, column=3, value=v).font = Font(name="Arial", size=10)
        r += 1

    r += 1
    ws.cell(row=r, column=2, value="Hojas del libro:").font = Font(name="Arial", bold=True, size=12, color="1F3864")
    r += 1
    sheets_desc = [
        ("1. Cutover OnPrem1 -> AWS", "Migracion inicial de la operacion desde On-Premise 1 hacia AWS (deja OnPrem1 fuera)."),
        ("2. Failover AWS -> OnPrem2", "Activacion de contingencia: pasar la operacion a On-Premise 2 (DR)."),
        ("3. Failback OnPrem2 -> AWS", "Retorno controlado de la operacion a AWS, dejando OnPrem2 como DR."),
        ("Arquitectura y componentes", "Referencia de recursos (ALB, 7 ASG, RDS x2, FSx, DMS 8 tasks, Imperva, DFS-R)."),
    ]
    for name, desc in sheets_desc:
        ws.cell(row=r, column=2, value=name).font = Font(name="Arial", bold=True, size=10, color="2E75B6")
        ws.cell(row=r, column=3, value=desc).font = Font(name="Arial", size=10)
        ws.row_dimensions[r].height = 16
        r += 1

    r += 1
    ws.merge_cells(start_row=r, start_column=2, end_row=r, end_column=3)
    ws.cell(row=r, column=2,
            value=("Fases (segun Change Request ServiceNow): Pre Implementation -> Implementation -> "
                   "Go/No-Go -> Post Implementation -> Backout. Estado inicial de cada tarea: Draft.")).font = \
        Font(name="Arial", italic=True, size=9, color="666666")
    ws.row_dimensions[r].height = 30


def arch_sheet(wb):
    ws = wb.create_sheet(title="Arquitectura y componentes")
    cols = [("Componente", 30), ("Detalle", 70), ("Rol en DR", 40)]
    for i, (n, w) in enumerate(cols, start=1):
        cell = ws.cell(row=1, column=i, value=n)
        cell.fill = HEADER_FILL; cell.font = HEADER_FONT; cell.alignment = CENTER; cell.border = BORDER
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.row_dimensions[1].height = 24
    ws.freeze_panes = "A2"
    data = [
        ("ALB interno", "eec-aws-us-eits-prod. Routing host-based a 7 target groups (una por app). HTTP:80 (HTTPS:443/ACM pendiente).", "Punto de entrada de las apps en AWS."),
        ("ASG (7 apps)", "r7a.medium, min1/max2, CPU target tracking 70%, IIS baked. Montan FSx (Z:) y configuran sitios IIS.", "Capa de computo en AWS (equivalente a IIS por app en OnPrem2)."),
        ("RDS produccion", "SQL Server SE 15, db.r6i.4xlarge, 1700GB, Multi-AZ, SSIS+SSRS+TDE.", "BD principal en AWS. Replica via DMS a OnPrem2."),
        ("RDS procesos", "SQL Server SE 15, db.r6i.2xlarge, 2900GB, Single-AZ, SSIS+SSRS.", "BD de procesos en AWS."),
        ("FSx Windows", "Single-AZ 1, 100GB SSD, 64MB/s, DFS-R, AD gdc.local, CMK propia. SG fsx-1..5.", "Contenido de los sitios IIS. DFS-R bidireccional con OnPrem2."),
        ("DMS", "Instancia poc (dms.c5.2xlarge, engine 3.6.1). 8 tareas CDC. Hoy: On-Prem->RDS; DR: AWS->OnPrem2.", "Replicacion de datos AWS <-> On-Premise."),
        ("Imperva (WAF/DNS)", "Firewall/WAF que publica las apps a internet, actua como DNS y ejecuta el failover/failback entre AWS y OnPrem2.", "Conmutador de trafico (failover automatico / failback controlado)."),
        ("On-Premise 2 (DR)", "Cluster SQL Server + 1 servidor IIS por app (sirve contenido desde DFS) + DFS replication groups.", "Sitio de contingencia (DR alterno)."),
        ("8 bases DMS", ", ".join(DMS_DBS), "Datos replicados AWS <-> OnPrem2."),
        ("8 sitios / host_headers", ", ".join(fqdn for _, fqdn, _ in APPS), "Aplicaciones publicadas por Imperva."),
    ]
    r = 2
    zebra = False
    for row in data:
        for i, v in enumerate(row, start=1):
            cell = ws.cell(row=r, column=i, value=v)
            cell.font = CELL_FONT; cell.border = BORDER; cell.alignment = WRAP_TOP
            if zebra: cell.fill = ALT_FILL
        ws.row_dimensions[r].height = 42
        r += 1
        zebra = not zebra


# ---------------------------------------------------------------- build ------
wb = Workbook()
wb.remove(wb.active)  # quitar hoja por defecto

cover_sheet(wb)
make_sheet(wb, "1. Cutover OnPrem1-AWS", "CHG-CUTOVER-OnPrem1toAWS",
           "Minutograma 1 - Cutover On-Premise 1 -> AWS (migracion inicial)", cutover)
make_sheet(wb, "2. Failover AWS-OnPrem2", "CHG-FAILOVER-AWStoOnPrem2",
           "Minutograma 2 - Failover AWS -> On-Premise 2 (contingencia / DR)", failover)
make_sheet(wb, "3. Failback OnPrem2-AWS", "CHG-FAILBACK-OnPrem2toAWS",
           "Minutograma 3 - Failback On-Premise 2 -> AWS (retorno controlado)", failback)
arch_sheet(wb)

wb.save(OUT)
print("OK ->", OUT)
print("Hojas:", wb.sheetnames)
