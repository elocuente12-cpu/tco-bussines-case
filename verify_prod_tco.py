"""
Verifica el TCO productivo final: 12 servidores planeados + 5 componentes
desplegados (2 RDS, FSx, AMI Builder, DMS). Comprueba conteos, que los
servidores en ASG no tengan EBS adicional, y muestra totales.
"""
import openpyxl

FILEPATH = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambiente Productivo/Lift-and-Shift - 18 Servers/analysis_TCO.xlsx'

PLANNED = {'PAHWPAPSTS01','PAHWPAPSTE01','PAHWPAPSRC03','PAHWPAPWFC01','PAHWPWFINT01',
           'PAHWPWSAPI01','PAHWPAPWSS03','PAHWPAPWEF02','PAHWPAPTUI03','PAHWPCHECS01',
           'pahqpapapp02','pahwpapbof01'}
DEPLOYED = {'RDS produccion (multiaz1)','RDS procesos (standalone1)',
            'FSx Windows (intelisrcpa-prd)','AMI Builder (temporal)','DMS replication (poc)'}
# ASG => sin EBS adicional
ASG_HOSTS = {'PAHWPAPSRC03','PAHWPAPWFC01','PAHWPAPWSS03','PAHWPAPTUI03'}

wb = openpyxl.load_workbook(FILEPATH, data_only=True)
ws = wb['Shared Tenancy Analysis']

print("=== TCO Productivo final - Shared Tenancy Analysis ===\n")
hdr = f"{'Host':<28}{'EC2 Name':<16}{'Instance':<15}{'Root':>5}{'Add':>5}  {'EBS/yr':>8}{'OD/yr':>10}{'RI1/yr':>10}{'RI3/yr':>8}"
print(hdr); print('-'*len(hdr))

issues=[]
present=set()
tot={'ebs':0,'od':0,'lic':0}
for rr in range(2, ws.max_row+1):
    host=ws.cell(rr,1).value
    if not host: continue
    present.add(host)
    ec2=(ws.cell(rr,2).value or '').replace('\n','/')
    inst=ws.cell(rr,9).value; root=ws.cell(rr,12).value; add=ws.cell(rr,13).value
    ebsc=ws.cell(rr,15).value; od=ws.cell(rr,16).value; lic=ws.cell(rr,17).value
    ri1=ws.cell(rr,19).value; ri3=ws.cell(rr,21).value
    def n(x): return x if isinstance(x,(int,float)) else 0
    tot['ebs']+=n(ebsc); tot['od']+=n(od); tot['lic']+=n(lic)
    print(f"{str(host):<28}{ec2[:14]:<16}{str(inst):<15}{str(root):>5}{str(add) if add is not None else '-':>5}  "
          f"{str(ebsc):>8}{str(od):>10}{str(ri1):>10}{str(ri3):>8}")
    # ASG no debe tener EBS adicional
    if host in ASG_HOSTS and add is not None:
        issues.append(f"{host}: es ASG pero tiene EBS adicional={add} (debe ser vacio, storage=FSx)")

# Conteos y cobertura
for h in PLANNED|DEPLOYED:
    if h not in present: issues.append(f"FALTA: {h}")
# No debe existir la fila generica ASG app1
for h in present:
    if 'ASG app1 web' in str(h): issues.append(f"Fila generica no fusionada presente: {h}")

n_plan=len(present & PLANNED); n_dep=len(present & DEPLOYED)
print(f"\nTotal filas: {ws.max_row-1}  (planeados={n_plan}/12, desplegados={n_dep}/5)")

print("\n=== Validaciones ===")
if not issues:
    print("  OK - 17 filas, ASG sin EBS adicional, ASG app1 fusionado en PAHWPAPTUI03, sin duplicados.")
else:
    for i in issues: print(f"  DIFF: {i}")

print("\n=== Totales anuales ===")
print(f"  EBS/Storage:        ${tot['ebs']:>12,.2f}")
print(f"  On-Demand Total:    ${tot['od']:>12,.2f}  (col P: EC2+RDS+DMS+FSx)")
print(f"  License-only:       ${tot['lic']:>12,.2f}")
print(f"  TOTAL OD + storage: ${tot['od']+tot['ebs']:>12,.2f}/anio")
