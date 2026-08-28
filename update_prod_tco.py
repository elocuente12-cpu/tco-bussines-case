"""
Actualiza el TCO del ambiente PRODUCTIVO (intelisrcpa/pro) para reflejar el
estado REAL de la IaC desplegada.

Enfoque (confirmado con el usuario - Opcion A):
  El TCO original listaba 20 servidores del assessment lift-and-shift. La IaC
  realmente desplegada es una arquitectura re-diseñada (ASG + ALB + 2 RDS +
  FSx + AMI Builder + DMS). Se REEMPLAZA el inventario del assessment por los
  componentes reales desplegados, preservando la estructura de columnas y los
  estilos del encabezado.

Parametros confirmados:
  - ASG app1 (r7a.medium Windows): se costea desired_capacity = 2 instancias.
  - Se INCLUYE el AMI Builder (m5.large, temporal).

Fuente de precios: AWS Price List (us-east-1), shared tenancy, RI Standard
No-Upfront. 730 h/mes, anualizado x12.
Nota: RDS SQL Server SE License-included NO ofrece RI 3yr No-Upfront (solo
All/Partial Upfront), por eso esas celdas quedan en NA.
"""
import openpyxl
from copy import copy

FILEPATH = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambiente Productivo/Lift-and-Shift - 18 Servers/analysis_TCO.xlsx'

H = 730       # horas/mes
M = 12        # meses/anio
def yr(hr):   # anualizado desde $/hr
    return None if hr is None else round(hr * H * M, 2)

# ============ Precios reales AWS us-east-1 ($/hr salvo storage) ============
EBS_GP3 = 0.08              # $/GB-mes
FSX_SSD_SINGLE = 0.130     # $/GB-mes (Single-AZ SSD)
FSX_TP_SINGLE = 2.20       # $/MBps-mes (Single-AZ)
DMS_STORAGE = 0.115        # $/GB-mes

def ebs_yr(gb, mult=1):
    return round(gb * EBS_GP3 * M * mult, 2)

# EC2 Windows r7a.medium (total con licencia Windows / infra sin licencia)
r7a = {'od': 0.12208, 'ri1': 0.09632, 'ri3': 0.08051}
r7a_infra = {'od': 0.07608, 'ri1': 0.05032, 'ri3': 0.03451}
# EC2 Windows m5.large (AMI builder)
m5 = {'od': 0.188, 'ri1': 0.152, 'ri3': 0.133}
m5_infra = {'od': 0.096, 'ri1': 0.060, 'ri3': 0.041}
# RDS SQL Server SE license-included
rds4xl = {'od': 12.16, 'ri1': 11.4912}      # Multi-AZ
rds4xl_nolic = {'od': 5.952}
rds2xl = {'od': 3.04, 'ri1': 2.8728}        # Single-AZ
rds2xl_nolic = {'od': 1.488}
# DMS
dms_hr = 0.476

# ============ Filas reales segun IaC ============
# Cada dict mapea a las 22 columnas (A..V) del Excel.
servers = [
    # 1-2) ASG app1 (desired = 2) - r7a.medium Windows, root 120GB gp3
    *[{
        'host': f'ASG app1 web #{i}', 'ec2_name': f'USAEA1PWBWES2{i}', 'env': 'PROD',
        'cpus': 1, 'ram': 8, 'os_type': 'Windows', 'os_name': 'Microsoft Windows Server 2025 (ASG detras de ALB)',
        'rec': 'r7a.medium', 'dep': 'r7a.medium', 'cores': 1, 'aws_ram': 8,
        'ebs_root': 120, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': ebs_yr(120),
        'od_total': yr(r7a['od']), 'lic': yr(r7a['od'] - r7a_infra['od']), 'od_excl': yr(r7a_infra['od']),
        'ri1_total': yr(r7a['ri1']), 'ri1_excl': yr(r7a_infra['ri1']),
        'ri3_total': yr(r7a['ri3']), 'ri3_excl': yr(r7a_infra['ri3']),
    } for i in (1, 2)],

    # 3) RDS produccion - db.r6i.4xlarge Multi-AZ, storage 1700GB (x2 por Multi-AZ)
    {
        'host': 'RDS produccion (multiaz1)', 'ec2_name': None, 'env': 'PROD',
        'cpus': 16, 'ram': 128, 'os_type': 'SQL Server - Standard',
        'os_name': 'SQL Server Standard Edition 15.x (Multi-AZ, license-included)',
        'rec': 'db.r6i.4xlarge', 'dep': 'db.r6i.4xlarge', 'cores': 16, 'aws_ram': 128,
        'ebs_root': 1700, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': ebs_yr(1700, 2),
        'od_total': yr(rds4xl['od']), 'lic': yr(rds4xl['od'] - rds4xl_nolic['od']), 'od_excl': yr(rds4xl_nolic['od']),
        'ri1_total': yr(rds4xl['ri1']), 'ri1_excl': None,
        'ri3_total': 'NA', 'ri3_excl': 'NA',
    },

    # 4) RDS procesos - db.r6i.2xlarge Single-AZ, storage 2900GB
    {
        'host': 'RDS procesos (standalone1)', 'ec2_name': None, 'env': 'PROD',
        'cpus': 8, 'ram': 64, 'os_type': 'SQL Server - Standard',
        'os_name': 'SQL Server Standard Edition 15.x (Single-AZ, license-included)',
        'rec': 'db.r6i.2xlarge', 'dep': 'db.r6i.2xlarge', 'cores': 8, 'aws_ram': 64,
        'ebs_root': 2900, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': ebs_yr(2900, 1),
        'od_total': yr(rds2xl['od']), 'lic': yr(rds2xl['od'] - rds2xl_nolic['od']), 'od_excl': yr(rds2xl_nolic['od']),
        'ri1_total': yr(rds2xl['ri1']), 'ri1_excl': None,
        'ri3_total': 'NA', 'ri3_excl': 'NA',
    },

    # 5) FSx Windows Single-AZ SSD 100GB + 64 MBps throughput
    {
        'host': 'FSx Windows (intelisrcpa-prd)', 'ec2_name': None, 'env': 'PROD',
        'cpus': None, 'ram': None, 'os_type': 'Windows (FSx)',
        'os_name': 'FSx Windows File Server Single-AZ SSD (64 MBps, backup 30d)',
        'rec': 'FSx SINGLE_AZ_1', 'dep': 'FSx SINGLE_AZ_1', 'cores': None, 'aws_ram': None,
        'ebs_root': 100, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': round(100 * FSX_SSD_SINGLE * M, 2),           # storage
        'od_total': round(64 * FSX_TP_SINGLE * M, 2),             # throughput como costo del servicio
        'lic': 0, 'od_excl': round(64 * FSX_TP_SINGLE * M, 2),
        'ri1_total': None, 'ri1_excl': None, 'ri3_total': None, 'ri3_excl': None,
    },

    # 6) AMI Builder m5.large Windows (temporal)
    {
        'host': 'AMI Builder (temporal)', 'ec2_name': None, 'env': 'PROD',
        'cpus': 2, 'ram': 8, 'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2025 (AMI Builder - temporal)',
        'rec': 'm5.large', 'dep': 'm5.large', 'cores': 2, 'aws_ram': 8,
        'ebs_root': 100, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': ebs_yr(100),
        'od_total': yr(m5['od']), 'lic': yr(m5['od'] - m5_infra['od']), 'od_excl': yr(m5_infra['od']),
        'ri1_total': yr(m5['ri1']), 'ri1_excl': yr(m5_infra['ri1']),
        'ri3_total': yr(m5['ri3']), 'ri3_excl': yr(m5_infra['ri3']),
    },

    # 7) DMS replication c5.2xlarge Single-AZ 50GB
    {
        'host': 'DMS replication (poc)', 'ec2_name': None, 'env': 'PROD',
        'cpus': 8, 'ram': 16, 'os_type': 'DMS',
        'os_name': 'DMS c5.2xlarge Single-AZ (engine 3.6.1)',
        'rec': 'dms.c5.2xlarge', 'dep': 'dms.c5.2xlarge', 'cores': 8, 'aws_ram': 16,
        'ebs_root': 50, 'ebs_add': None, 'region': 'US East (N. Virginia)',
        'ebs_cost': round(50 * DMS_STORAGE * M, 2),
        'od_total': yr(dms_hr), 'lic': 0, 'od_excl': yr(dms_hr),
        'ri1_total': None, 'ri1_excl': None, 'ri3_total': None, 'ri3_excl': None,
    },
]

wb = openpyxl.load_workbook(FILEPATH)
ws = wb['Shared Tenancy Analysis']

# Capturar estilo de una celda de datos existente (fila 2) para replicarlo
data_style = []
for c in range(1, 23):
    cell = ws.cell(2, c)
    data_style.append({
        'font': copy(cell.font), 'alignment': copy(cell.alignment),
        'border': copy(cell.border), 'number_format': cell.number_format,
    })

# Limpiar TODAS las filas de datos (preservando encabezado, fila 1)
for row in ws.iter_rows(min_row=2, max_row=ws.max_row):
    for cell in row:
        cell.value = None

# Orden de columnas A..V (1..22)
def row_values(s):
    return [
        s['host'], s['ec2_name'], s['env'], s['cpus'], s['ram'], s['os_type'], s['os_name'],
        s['rec'], s['dep'], s['cores'], s['aws_ram'], s['ebs_root'], s['ebs_add'], s['region'],
        s['ebs_cost'], s['od_total'], s['lic'], s['od_excl'],
        s['ri1_total'], s['ri1_excl'], s['ri3_total'], s['ri3_excl'],
    ]

for idx, s in enumerate(servers, start=2):
    vals = row_values(s)
    for c, v in enumerate(vals, start=1):
        cell = ws.cell(row=idx, column=c)
        cell.value = v
        st = data_style[c - 1]
        cell.font = st['font']; cell.alignment = st['alignment']
        cell.border = st['border']; cell.number_format = st['number_format']

# Eliminar filas sobrantes del inventario anterior (assessment tenia 20 filas).
last_data_row = 1 + len(servers)
if ws.max_row > last_data_row:
    ws.delete_rows(last_data_row + 1, ws.max_row - last_data_row)

wb.save(FILEPATH)

print(f"TCO productivo actualizado con {len(servers)} componentes reales de la IaC.")
print("Componentes:")
for s in servers:
    print(f"  {s['host']:<32} {str(s['dep']):<16} EBS/stor={s['ebs_root']}GB  OD/yr={s['od_total']}  RI1/yr={s['ri1_total']}")
tot_ebs = sum((s['ebs_cost'] or 0) for s in servers)
tot_od = sum((s['od_total'] or 0) for s in servers)
tot_lic = sum((s['lic'] or 0) for s in servers)
print(f"\nTotales anuales: EBS/storage=${tot_ebs:,.2f}  OD(EC2+RDS+DMS+FSx)=${tot_od:,.2f}  License-only=${tot_lic:,.2f}")
print(f"Gran total anual (OD + storage) = ${tot_od + tot_ebs:,.2f}")
