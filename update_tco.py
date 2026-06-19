import openpyxl
from copy import copy

filepath = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambientes intermedios/Assessment-2026-03-04-1706/analysis_TCO.xlsx'
wb = openpyxl.load_workbook(filepath)

ws = wb['Shared Tenancy Analysis']

# Clear existing data rows (keep header)
for row in ws.iter_rows(min_row=2, max_row=ws.max_row):
    for cell in row:
        cell.value = None

# Define all servers from IaC (source of truth)
# Columns:
# A: Host Name Onpremise
# B: EC2 Name
# C: Environment
# D: Number of CPUs
# E: RAM (GB)
# F: Operation System Type
# G: Operation System Name
# H: AWS Instance Recommended
# I: AWS Instance Deploy
# J: AWS Total Cores
# K: AWS RAM (GB)
# L: EBS Size (GB) - Root
# M: EBS Size (GB) - Additional
# N: AWS Region

servers = [
    # === STG/UAT Environment ===
    {
        'host_name': 'PAHQTAPIIS01',
        'ec2_name': 'USAEA1UAPWES01',
        'environment': 'UAT',
        'cpus': 4,
        'ram': 16,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2016 or later',
        'instance_recommended': 'm5a.xlarge',
        'instance_deploy': 'm5a.xlarge',
        'total_cores': 4,
        'aws_ram': 16,
        'ebs_root': 130,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTFSDSC01',
        'ec2_name': 'USAEA1UAPWES02',
        'environment': 'UAT',
        'cpus': 4,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2022',
        'instance_recommended': 'c5a.xlarge',
        'instance_deploy': 'c5a.xlarge',
        'total_cores': 4,
        'aws_ram': 8,
        'ebs_root': 100,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTWFINT01',
        'ec2_name': 'USAEA1UAPWES03',
        'environment': 'UAT',
        'cpus': 4,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2019',
        'instance_recommended': 'c5a.xlarge',
        'instance_deploy': 'c5a.xlarge',
        'total_cores': 4,
        'aws_ram': 8,
        'ebs_root': 80,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTAPSTE01',
        'ec2_name': 'USAEA1UAPLES01',
        'environment': 'UAT',
        'cpus': 2,
        'ram': 4,
        'os_type': 'RHEL',
        'os_name': 'Red Hat Enterprise Linux 8',
        'instance_recommended': 'c5a.large',
        'instance_deploy': 'c5a.large',
        'total_cores': 2,
        'aws_ram': 4,
        'ebs_root': 210,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTAPSTS01',
        'ec2_name': 'USAEA1UAPLES02',
        'environment': 'UAT',
        'cpus': 2,
        'ram': 8,
        'os_type': 'RHEL',
        'os_name': 'Red Hat Enterprise Linux 8',
        'instance_recommended': 'm5.large',
        'instance_deploy': 'm5.large',
        'total_cores': 2,
        'aws_ram': 8,
        'ebs_root': 520,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTAPBOF01',
        'ec2_name': 'USAEA1UAPLES03',
        'environment': 'UAT',
        'cpus': 2,
        'ram': 8,
        'os_type': 'Linux',
        'os_name': 'Ubuntu Linux',
        'instance_recommended': 'm5.large',
        'instance_deploy': 'm5.large',
        'total_cores': 2,
        'aws_ram': 8,
        'ebs_root': 80,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    # === DEV Environment ===
    {
        'host_name': 'SSRP',
        'ec2_name': '',
        'environment': 'DEV',
        'cpus': 4,
        'ram': 16,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2019',
        'instance_recommended': 'm5.xlarge',
        'instance_deploy': 'm5.xlarge',
        'total_cores': 4,
        'aws_ram': 16,
        'ebs_root': 100,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQDAPIIS01',
        'ec2_name': '',
        'environment': 'DEV',
        'cpus': 2,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2019',
        'instance_recommended': 'm5a.large',
        'instance_deploy': 'm5a.large',
        'total_cores': 2,
        'aws_ram': 8,
        'ebs_root': 100,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQDWFINT01',
        'ec2_name': '',
        'environment': 'DEV',
        'cpus': 4,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2022',
        'instance_recommended': 'c5a.xlarge',
        'instance_deploy': 'c5a.xlarge',
        'total_cores': 4,
        'aws_ram': 8,
        'ebs_root': 100,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    # === QA/TST Environment ===
    {
        'host_name': 'PAHQDAPWSS01',
        'ec2_name': '',
        'environment': 'QA',
        'cpus': 2,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2019',
        'instance_recommended': 'm5.large',
        'instance_deploy': 'm5.large',
        'total_cores': 2,
        'aws_ram': 8,
        'ebs_root': 100,
        'ebs_additional': 100,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'PAHQTWFINT02',
        'ec2_name': '',
        'environment': 'QA',
        'cpus': 4,
        'ram': 8,
        'os_type': 'Windows',
        'os_name': 'Microsoft Windows Server 2019',
        'instance_recommended': 'c5a.xlarge',
        'instance_deploy': 'c5a.xlarge',
        'total_cores': 4,
        'aws_ram': 8,
        'ebs_root': 80,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    # === RDS Instances ===
    {
        'host_name': 'RDS SQL Server (UAT)',
        'ec2_name': '',
        'environment': 'UAT',
        'cpus': 2,
        'ram': 16,
        'os_type': 'SQL Server - Standard',
        'os_name': 'SQL Server Standard Edition 15.x',
        'instance_recommended': 'db.r5.large',
        'instance_deploy': 'db.r5.large',
        'total_cores': 2,
        'aws_ram': 16,
        'ebs_root': 200,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'RDS SQL Server (DEV)',
        'ec2_name': '',
        'environment': 'DEV',
        'cpus': 4,
        'ram': 16,
        'os_type': 'SQL Server - Developer',
        'os_name': 'SQL Server Developer Edition 16.x',
        'instance_recommended': 'db.m6i.xlarge',
        'instance_deploy': 'db.m6i.xlarge',
        'total_cores': 4,
        'aws_ram': 16,
        'ebs_root': 500,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
    {
        'host_name': 'RDS SQL Server (QA)',
        'ec2_name': '',
        'environment': 'QA',
        'cpus': 2,
        'ram': 16,
        'os_type': 'SQL Server - Standard',
        'os_name': 'SQL Server Standard Edition 15.x',
        'instance_recommended': 'db.r5.large',
        'instance_deploy': 'db.r5.large',
        'total_cores': 2,
        'aws_ram': 16,
        'ebs_root': 200,
        'ebs_additional': None,
        'region': 'US East (N. Virginia)',
    },
]

# Write data
for idx, server in enumerate(servers, start=2):
    ws.cell(row=idx, column=1, value=server['host_name'])
    ws.cell(row=idx, column=2, value=server['ec2_name'])
    ws.cell(row=idx, column=3, value=server['environment'])
    ws.cell(row=idx, column=4, value=server['cpus'])
    ws.cell(row=idx, column=5, value=server['ram'])
    ws.cell(row=idx, column=6, value=server['os_type'])
    ws.cell(row=idx, column=7, value=server['os_name'])
    ws.cell(row=idx, column=8, value=server['instance_recommended'])
    ws.cell(row=idx, column=9, value=server['instance_deploy'])
    ws.cell(row=idx, column=10, value=server['total_cores'])
    ws.cell(row=idx, column=11, value=server['aws_ram'])
    ws.cell(row=idx, column=12, value=server['ebs_root'])
    ws.cell(row=idx, column=13, value=server.get('ebs_additional'))
    ws.cell(row=idx, column=14, value=server['region'])

wb.save(filepath)
print(f"TCO actualizado exitosamente con {len(servers)} registros basados en la IaC.")
print(f"  - EC2 Windows: {sum(1 for s in servers if 'Windows' in s['os_type'])}")
print(f"  - EC2 Linux: {sum(1 for s in servers if s['os_type'] in ['RHEL', 'Linux'])}")
print(f"  - RDS: {sum(1 for s in servers if 'RDS' in s['host_name'])}")
