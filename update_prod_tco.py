import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side, PatternFill
from copy import copy

# Read the intermediate environments TCO to get the target format/headers
ref_filepath = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambientes intermedios/Assessment-2026-03-04-1706/analysis_TCO.xlsx'
ref_wb = openpyxl.load_workbook(ref_filepath)
ref_ws = ref_wb['Shared Tenancy Analysis']

# Get target headers and styles from reference
target_headers = [cell.value for cell in ref_ws[1]]
header_styles = []
for cell in ref_ws[1]:
    header_styles.append({
        'font': copy(cell.font),
        'alignment': copy(cell.alignment),
        'border': copy(cell.border),
        'fill': copy(cell.fill),
        'number_format': cell.number_format,
    })

print(f"Target format headers ({len(target_headers)} cols): {target_headers}")

# Read the production file
prod_filepath = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambiente Productivo/Lift-and-Shift - 18 Servers/analysis.xlsx'
prod_wb = openpyxl.load_workbook(prod_filepath, data_only=True)

# Read On-Demand sheet for cost data
ws_od = prod_wb['Shared Tenancy - On-Demand']
# Read 1yr NU for 1yr costs
ws_1yr = prod_wb['Shared Tenancy - 1yr NU']
# Read 3yr NU for 3yr costs
ws_3yr = prod_wb['Shared Tenancy - 3yr NU']

# Extract server data from On-Demand (rows 2-19 are the 18 assessment servers)
# Columns in source: 0:Server Id, 1:Server Name, 2:Host Name, 3:Cluster Name, 4:Hypervisor,
# 5:Environment, 6:Application, 7:Server Type, 8:Number of CPUs, 9:Cores per CPU,
# 10:Total Cores, 11:RAM (GB), 12:Operating System Type, 13:Operating System Name,
# 14:Peak CPU %, 15:Avg CPU %, 16:Peak RAM %, 17:Avg RAM %, 18:Uptime %,
# 19:EC2 Instance Recommended, 20:EC2 Total Cores, 21:EC2 RAM (GB), 22:AWS Region,
# 23:Annualized Total Cost, 24:Annualized Network Cost, 25:Annualized License Only Cost,
# 26:Annualized EC2 Cost Excl. License Cost

# The last 3 rows (20-22 in sheet, rows 31 area) have different format:
# Server-Hostname | IP | vCPU | Memory (GiB) | General Purpose (GB) | Environment Type | OS Name | OS Version | APP Description

servers_data = []

# Process the 18 assessment servers (rows 2-19)
for row_idx in range(2, 20):
    row = [cell.value for cell in ws_od[row_idx]]
    
    server_name = row[1]  # Server Name
    cpus = row[8] if row[8] else row[10]  # Number of CPUs or Total Cores
    ram = row[11]  # RAM (GB)
    os_type = row[12]  # Operating System Type
    os_name = row[13]  # Operating System Name
    instance_recommended = row[19]  # EC2 Instance Recommended
    ec2_cores = row[20]  # EC2 Total Cores
    ec2_ram = row[21]  # EC2 RAM (GB)
    region = row[22]  # AWS Region

    # Cost from On-Demand
    od_total_cost = row[23]
    od_license_cost = row[25]
    od_ec2_cost = row[26]

    # Cost from 1yr NU
    row_1yr = [cell.value for cell in ws_1yr[row_idx]]
    yr1_total_cost = row_1yr[23]
    yr1_ec2_cost = row_1yr[26]

    # Cost from 3yr NU
    row_3yr = [cell.value for cell in ws_3yr[row_idx]]
    yr3_total_cost = row_3yr[23]
    yr3_ec2_cost = row_3yr[26]

    servers_data.append({
        'host_name': server_name,
        'ec2_name': '',
        'environment': 'PROD',
        'cpus': cpus,
        'ram': ram,
        'os_type': os_type,
        'os_name': os_name,
        'instance_recommended': instance_recommended,
        'instance_deploy': instance_recommended,  # Same as recommended for prod
        'total_cores': ec2_cores,
        'aws_ram': ec2_ram,
        'ebs_root': None,  # Will fill from EBS data
        'ebs_additional': None,
        'region': 'US East (N. Virginia)' if region == 'us-east-1' else region,
        'od_total_cost': od_total_cost,
        'od_license_cost': od_license_cost,
        'od_ec2_cost': od_ec2_cost,
        'yr1_total_cost': yr1_total_cost,
        'yr1_ec2_cost': yr1_ec2_cost,
        'yr3_total_cost': yr3_total_cost,
        'yr3_ec2_cost': yr3_ec2_cost,
    })

# Process the 3 additional servers (rows 20-22 in the sheet, different format)
for row_idx in range(20, 23):
    row = [cell.value for cell in ws_od[row_idx]]
    if row[0] is None:
        continue
    # Format: Server-Hostname | IP | vCPU | Memory (GiB) | General Purpose (GB) | Environment Type | OS Name | OS Version | APP Description
    server_name = row[0]
    vcpu = row[2]
    memory = row[3]
    ebs_size = row[4]
    env_type = row[5]
    os_name_short = row[6]
    os_version = row[7]

    # Determine OS type
    if os_name_short and 'Windows' in str(os_name_short):
        os_type = 'Windows'
        os_full = f"{os_version}" if os_version else os_name_short
    elif os_name_short and 'Linux' in str(os_name_short):
        os_type = 'Linux'
        os_full = f"{os_version}" if os_version else os_name_short
    else:
        os_type = str(os_name_short) if os_name_short else ''
        os_full = str(os_version) if os_version else ''

    servers_data.append({
        'host_name': server_name,
        'ec2_name': '',
        'environment': 'PROD',
        'cpus': vcpu,
        'ram': memory,
        'os_type': os_type,
        'os_name': os_full,
        'instance_recommended': '',  # Not assessed
        'instance_deploy': '',  # Not assessed
        'total_cores': vcpu,
        'aws_ram': memory,
        'ebs_root': ebs_size,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
        'od_total_cost': None,
        'od_license_cost': None,
        'od_ec2_cost': None,
        'yr1_total_cost': None,
        'yr1_ec2_cost': None,
        'yr3_total_cost': None,
        'yr3_ec2_cost': None,
    })

# Now create the output file with the same format as intermedios
# We'll overwrite the production analysis.xlsx with a new "Shared Tenancy Analysis" sheet
# but keep the original sheets (Read Me, Glossary, etc.)

# Reload production file (not data_only) so we can modify it
prod_wb_write = openpyxl.load_workbook(prod_filepath)

# Create new sheet with the target format
if 'Shared Tenancy Analysis' in prod_wb_write.sheetnames:
    del prod_wb_write['Shared Tenancy Analysis']

# Insert after 'Glossary' if possible
glossary_idx = prod_wb_write.sheetnames.index('Glossary') if 'Glossary' in prod_wb_write.sheetnames else 1
ws_new = prod_wb_write.create_sheet('Shared Tenancy Analysis', glossary_idx + 1)

# Write headers matching the intermedios format
for col_idx, header in enumerate(target_headers, start=1):
    cell = ws_new.cell(row=1, column=col_idx, value=header)
    if col_idx - 1 < len(header_styles):
        style = header_styles[col_idx - 1]
        cell.font = style['font']
        cell.alignment = style['alignment']
        cell.border = style['border']
        cell.fill = style['fill']

# Write server data
# Target columns: Host Name Onpremise | EC2 Name | Environment | Number of CPUs | RAM (GB) |
# Operation System Type | Operation System Name | AWS Instance Recommended | AWS Instance Deploy |
# AWS Total Cores | AWS RAM (GB) | EBS Size (GB) Root | EBS Size (GB) Additional | AWS Region |
# Annualized 1 Yr EBS Cost | Annualized On-Demand Total EC2 - RDS Cost | Annualized License Only Cost |
# Annualized On-Demand EC2 Cost Excl. License Cost | Annualized 1 Yr NURI Total EC2 - RDS Cost |
# Annualized 1 Yr NURI EC2 Cost, Excl. License Costs | Annualized 3 Yr NURI Total EC2 Cost |
# Annualized 3 Yr NURI EC2 Cost Excl. License Cost

for idx, server in enumerate(servers_data, start=2):
    ws_new.cell(row=idx, column=1, value=server['host_name'])
    ws_new.cell(row=idx, column=2, value=server['ec2_name'])
    ws_new.cell(row=idx, column=3, value=server['environment'])
    ws_new.cell(row=idx, column=4, value=server['cpus'])
    ws_new.cell(row=idx, column=5, value=server['ram'])
    ws_new.cell(row=idx, column=6, value=server['os_type'])
    ws_new.cell(row=idx, column=7, value=server['os_name'])
    ws_new.cell(row=idx, column=8, value=server['instance_recommended'])
    ws_new.cell(row=idx, column=9, value=server['instance_deploy'])
    ws_new.cell(row=idx, column=10, value=server['total_cores'])
    ws_new.cell(row=idx, column=11, value=server['aws_ram'])
    ws_new.cell(row=idx, column=12, value=server['ebs_root'])
    ws_new.cell(row=idx, column=13, value=server['ebs_additional'])
    ws_new.cell(row=idx, column=14, value=server['region'])
    # Cost columns (15-22)
    ws_new.cell(row=idx, column=15, value=None)  # EBS Cost - not available from source
    ws_new.cell(row=idx, column=16, value=server['od_total_cost'])
    ws_new.cell(row=idx, column=17, value=server['od_license_cost'])
    ws_new.cell(row=idx, column=18, value=server['od_ec2_cost'])
    ws_new.cell(row=idx, column=19, value=server['yr1_total_cost'])
    ws_new.cell(row=idx, column=20, value=server['yr1_ec2_cost'])
    ws_new.cell(row=idx, column=21, value=server['yr3_total_cost'])
    ws_new.cell(row=idx, column=22, value=server['yr3_ec2_cost'])

# Save
prod_wb_write.save(prod_filepath)
print(f"\nArchivo de produccion actualizado exitosamente.")
print(f"Se agrego sheet 'Shared Tenancy Analysis' con formato homologado.")
print(f"Total servidores: {len(servers_data)}")
print(f"  - Windows: {sum(1 for s in servers_data if 'Win' in str(s['os_type']))}")
print(f"  - Linux/RHEL: {sum(1 for s in servers_data if s['os_type'] in ['RHEL', 'Linux'])}")
print(f"\nServidores incluidos:")
for s in servers_data:
    print(f"  {s['host_name']:<20} {s['environment']:<6} {s['os_type']:<10} {str(s['instance_recommended']):<15} EBS={s['ebs_root']}")
