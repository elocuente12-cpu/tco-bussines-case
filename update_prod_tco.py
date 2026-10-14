"""
Reconstruye el TCO PRODUCTIVO segun el estado ACTUAL de la IaC (intelisrcpa/pro).

Cambios reflejados (auditoria v2):
  - 3 EC2 standalone reales (ec2_windows): USAEA1PFSWES08/09, USAEA1PAPWES34.
  - 7 ASG (alb_apps app1..app7), prefijos PA..PG. Se costea 1 instancia por ASG
    (desired=1). app6 esta en desired=0 temporal pero se costea igual.
  - RDS produccion (Multi-AZ) y procesos (Single-AZ): sin cambios.
  - FSx actualizado a 150 GB.
  - AMI Builder: se CONSERVA (hoy create_ami_builder_instance=false, pero se
    usara cuando se requiera).
  - DMS: 2 replication instances (poc + rpi), dms.c5.2xlarge c/u.
  - Datadog DBM: EC2 t3.medium Linux (nuevo).
  - Servicios: ALB (7 TG), ASG Lifecycle, S3, Secrets Manager, CloudWatch.

Reglas:
  - ASG: hostname on-premise (col A) en BLANCO; col B = nombre AWS (prefijo).
  - Solo recursos AWS (licencias Datadog SaaS excluidas).
  - Columnas de costo identicas al criterio previo (A..AB).

Precios AWS us-east-1, shared, RI Standard No-Upfront, 730 h/mes, anualizado x12.
Nota: RDS SQL SE license-included no tiene RI 3yr No-Upfront (AA/AB -> NA en RDS,
   conservando lo que ya habia el usuario para RDS produccion/procesos).
"""
import openpyxl
from copy import copy

FILEPATH = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambiente Productivo/Lift-and-Shift - 18 Servers/analysis_TCO.xlsx'
H = 730
M = 12
def yr(hr): return None if hr is None else round(hr*H*M, 2)
def mo(hr): return None if hr is None else round(hr*H, 2)
EBS = 0.08
def ebs_mo(gb, mult=1): return None if gb is None else round(gb*EBS*mult, 2)
def ebs_yr(gb, mult=1): return None if gb is None else round(gb*EBS*mult*M, 2)

# Precios $/hr (total con licencia Windows / infra sin licencia)
P = {
 'm5.large':   {'win':(0.188,0.152,0.133), 'inf':(0.096,0.060,0.041)},
 'm5a.xlarge': {'win':(0.356,0.292,0.258), 'inf':(0.172,0.108,0.074)},
 'r5a.large':  {'win':(0.205,0.163,0.141), 'inf':(0.113,0.071,0.049)},
 't3.medium':  {'lin':(0.0416,0.0261,0.018)},
}

def win_row(hostA, ec2B, osname, inst, cores, ram, root, add, cpus=None, ramgb=None):
    """Fila Windows (licencia incluida)."""
    od,ri1,ri3 = P[inst]['win']
    iod,iri1,iri3 = P[inst]['inf']
    return dict(A=hostA, B=ec2B, C='PROD', D=cpus or cores, E=ramgb or ram, F='Windows', G=osname,
        H=inst, I=inst, J=cores, K=ram, L=root, M=add, N='US East (N. Virginia)',
        O=ebs_mo(root), P=ebs_yr(root), Q=ebs_mo(add), R=ebs_yr(add),
        S=mo(od), T=yr(od), U=yr(od-iod), V=yr(iod),
        W=mo(ri1), X=yr(ri1), Y=yr(iri1), Z=mo(ri3), AA=yr(ri3), AB=yr(iri3))

def lin_row(hostA, ec2B, osname, inst, cores, ram, root, add):
    """Fila Linux (sin licencia)."""
    od,ri1,ri3 = P[inst]['lin']
    return dict(A=hostA, B=ec2B, C='PROD', D=cores, E=ram, F='Linux', G=osname,
        H=inst, I=inst, J=cores, K=ram, L=root, M=add, N='US East (N. Virginia)',
        O=ebs_mo(root), P=ebs_yr(root), Q=ebs_mo(add), R=ebs_yr(add),
        S=mo(od), T=yr(od), U=0, V=yr(od),
        W=mo(ri1), X=yr(ri1), Y=yr(ri1), Z=mo(ri3), AA=yr(ri3), AB=yr(ri3))

def svc_row(name, det, monthly, annual):
    return dict(A=name, B=None, C='PROD', F='Servicio', G=det, H='-', I='-',
        N='US East (N. Virginia)', S=round(monthly,2), T=round(annual,2))

rows = []

# ---- A) EC2 standalone (3) ----
rows.append(win_row('PAHWPFSASC01','USAEA1PFSWES08','Microsoft Windows Server 2025 (64-bit)','m5.large',2,8,240,None))
rows.append(win_row('PAHWPWFINT01','USAEA1PFSWES09','Microsoft Windows Server 2025 (64-bit)','m5.large',2,8,100,300))
rows.append(win_row('PAHWPAPWEF02','USAEA1PAPWES34','Microsoft Windows Server 2025 (64-bit)','m5a.xlarge',4,16,100,90))

# ---- B) ASG app1..app7 (desired=1, hostname onprem en blanco) ----
asg = [
 ('USAEA1PWBWESPA','app1 (mobile/tuintelidat/apcexperian)','m5.large',2,8),
 ('USAEA1PWBWESPB','app2 (online.intelidat)','r5a.large',2,16),
 ('USAEA1PWBWESPC','app3 (webfolder)','m5.large',2,8),
 ('USAEA1PWBWESPD','app4 (webservices)','m5.large',2,8),
 ('USAEA1PWBWESPE','app5 (api)','r5a.large',2,16),
 ('USAEA1PWBWESPF','app6 (miexperian.cl, desired 0 temporal)','r5a.large',2,16),
 ('USAEA1PWBWESPG','app7 (apps/dashboard)','m5.large',2,8),
]
for ec2, desc, inst, cores, ram in asg:
    rows.append(win_row(None, ec2, f'Microsoft Windows Server 2025 (64-bit) [ASG {desc}]', inst, cores, ram, 120, None))

# ---- C) Datos / otros ----
# RDS: conservar valores que el usuario ya tenia (incluye RI 3yr y storage Multi-AZ).
rds_prod = dict(A='RDS produccion (multiaz1)', B=None, C='PROD', D=16, E=128,
    F='SQL Server - Standard', G='SQL Server Standard Edition 15.x (Multi-AZ, license-included)',
    H='db.r6i.4xlarge', I='db.r6i.4xlarge', J=16, K=128, L=1700, M=None, N='US East (N. Virginia)',
    O=391, P=4692, S=8876.8, T=106521.6, U=54382.08, V=52139.52,
    W=8388.58, X=100662.96, Y=None, Z=20878.25, AA=250539, AB='NA')
rds_proc = dict(A='RDS procesos (standalone1)', B=None, C='PROD', D=8, E=64,
    F='SQL Server - Standard', G='SQL Server Standard Edition 15.x (Single-AZ, license-included)',
    H='db.r6i.2xlarge', I='db.r6i.2xlarge', J=8, K=64, L=2900, M=None, N='US East (N. Virginia)',
    O=333.5, P=4002, S=2219.2, T=26630.4, U=13595.52, V=13034.88,
    W=2097.14, X=25165.68, Y=None, Z=5219.58, AA=62635, AB='NA')
rows.append(rds_prod)
rows.append(rds_proc)

# FSx 150 GB (storage 150*0.13=19.5/mo; throughput 64*2.20=140.8/mo). Mismo criterio previo:
# O/P = storage; S/T = throughput (costo del servicio).
fsx_storage_mo = round(150*0.130, 2); fsx_tp_mo = round(64*2.20, 2)
rows.append(dict(A='FSx Windows (intelisrcpa-prd)', B=None, C='PROD', F='Windows (FSx)',
    G='FSx Windows File Server Single-AZ SSD 150GB (64 MBps, backup 30d)',
    H='FSx SINGLE_AZ_1', I='FSx SINGLE_AZ_1', L=150, N='US East (N. Virginia)',
    O=fsx_storage_mo, P=round(fsx_storage_mo*M,2), S=fsx_tp_mo, T=round(fsx_tp_mo*M,2), U=0, V=round(fsx_tp_mo*M,2)))

# AMI Builder (se conserva) m5.large Windows root 100
rows.append(win_row('AMI Builder (temporal)', None, 'Microsoft Windows Server 2025 (AMI Builder - temporal, hoy inactivo)', 'm5.large', 2, 8, 100, None))

# DMS poc + rpi (dms.c5.2xlarge Single-AZ 50GB) - DMS no cobra licencia; mismo criterio previo (sin RI)
for key in ['poc','rpi']:
    rows.append(dict(A=f'DMS replication ({key})', B=None, C='PROD', D=8, E=16, F='DMS',
        G=f'DMS c5.2xlarge Single-AZ (engine 3.6.1) - {key}', H='dms.c5.2xlarge', I='dms.c5.2xlarge',
        J=8, K=16, L=50, N='US East (N. Virginia)',
        O=round(50*EBS,2), P=round(50*EBS*M,2), S=mo(0.476), T=yr(0.476), U=0, V=yr(0.476)))

# Datadog DBM EC2 t3.medium Linux (nuevo)
rows.append(lin_row('Datadog DBM', None, 'Amazon Linux (Datadog Database Monitoring) t3.medium', 't3.medium', 2, 4, 30, None))

# ---- D) Servicios (ALB con 7 TG) ----
alb_mo = round(0.0225*H + 0.008*H*7, 2)   # 1 ALB + 7 LCU (7 target groups)
rows.append(svc_row('Application Load Balancer (eec-aws-us-eits-prod)', 'ALB internal (7 TG/host-header)', alb_mo, round(alb_mo*M,2)))
# NLB internal delante del ALB (ingress EEC e-Connect via TGW): TCP:443 passthrough.
nlb_mo = round(0.0225*H + 0.006*H*1, 2)   # 1 NLB + ~1 NLCU
rows.append(svc_row('Network Load Balancer (eec-aws-us-eits-prod-nlb)', 'NLB internal TCP:443 passthrough -> ALB (ingress TGW)', nlb_mo, round(nlb_mo*M,2)))
rows.append(svc_row('ASG Lifecycle (Lambda leave-domain)', 'Lambda py3.12 128MB + EventBridge + CW Logs', 0.12, 1.44))
rows.append(svc_row('S3 (rds-backup + rds-ssis + bootstrap + backup-reports)', '4 buckets Standard', 1.50, 18.00))
rows.append(svc_row('Secrets Manager (AD/DMS + site certificates)', '~18 secrets (5 base + site certs)', round(18*0.40,2), round(18*0.40*M,2)))
rows.append(svc_row('CloudWatch (alarmas ALB/ASG + metricas)', 'alarmas 7 TG + metricas', 1.40, 16.80))
# AWS Backup: planes diario (ret 30d) + mensual (ret 1825d). Volumen protegido
# (backup=yes): EBS ~1700GB + RDS 4600GB + FSx 150GB. Estimacion conservadora
# factor 1.5x sobre volumen (incrementales + copias). EBS $0.05, RDS $0.095, FSx $0.05 /GB-mes.
rows.append(svc_row('AWS Backup (vault + plan diario 30d + mensual 1825d)', 'snapshots EBS/RDS/FSx (backup=yes), factor 1.5x', 794.25, 9531.00))
# KMS: 6 CMKs (ebs, rds, s3, secrets, aws_backup vault, sns) x $1/mes.
rows.append(svc_row('KMS (6 CMKs: ebs/rds/s3/secrets/backup/sns)', '6 customer managed keys x $1', 6.00, 72.00))
# SNS + ACM: bajo volumen / certificados publicos = ~$0 (constancia).
rows.append(svc_row('SNS (alertas ACM/backup) + ACM (certificados)', 'notificaciones + certs publicos', 0.00, 0.00))

# ===== Escritura =====
wb = openpyxl.load_workbook(FILEPATH)
ws = wb['Shared Tenancy Analysis']
ncol = ws.max_column
style = []
for c in range(1, ncol+1):
    cell = ws.cell(2, c)
    style.append({'font':copy(cell.font),'alignment':copy(cell.alignment),'border':copy(cell.border),'number_format':cell.number_format})

for row in ws.iter_rows(min_row=2, max_row=ws.max_row):
    for cell in row:
        cell.value = None

from openpyxl.utils import column_index_from_string
def colnum(letter): return column_index_from_string(letter)

for idx, rd in enumerate(rows, start=2):
    for letter, val in rd.items():
        c = colnum(letter)
        cell = ws.cell(row=idx, column=c)
        cell.value = val
        st = style[c-1]
        cell.font=st['font']; cell.alignment=st['alignment']; cell.border=st['border']; cell.number_format=st['number_format']

last = 1 + len(rows)
if ws.max_row > last:
    ws.delete_rows(last+1, ws.max_row - last)
for _r,_dim in list(ws.row_dimensions.items()):
    if _dim.hidden: _dim.hidden = False

wb.save(FILEPATH)
print(f"TCO prod reconstruido: {len(rows)} filas.")
for i,rd in enumerate(rows, start=2):
    print(f"  R{i}: A={rd.get('A')!r:<42} B={rd.get('B')!r:<22} inst={rd.get('H')} root={rd.get('L')} add={rd.get('M')}")
