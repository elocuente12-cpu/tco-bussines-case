import openpyxl

filepath = '/Users/javier.sepulveda/projects/experian/tco-bussines-case/Ambiente Productivo/Lift-and-Shift - 18 Servers/analysis_TCO.xlsx'
wb = openpyxl.load_workbook(filepath, data_only=True)
ws = wb['Shared Tenancy Analysis']

print("=== TCO Productivo Reformateado - Shared Tenancy Analysis ===\n")
print(f"{'#':<3} {'Host Name':<20} {'Env':<5} {'Instance Deploy':<15} {'Cores':<6} {'RAM':<5} {'EBS Root':<10} {'EBS Add':<8} {'OS Type':<10}")
print("-" * 95)

count = 0
for row in ws.iter_rows(min_row=2, max_row=ws.max_row, values_only=True):
    if row[0] is None:
        continue
    count += 1
    host = row[0] or ''
    env = row[2] or ''
    instance = row[8] or ''
    cores = row[9] or ''
    ram = row[10] or ''
    ebs_root = row[11] or ''
    ebs_add = row[12] or '-'
    os_type = row[5] or ''
    print(f"{count:<3} {str(host):<20} {str(env):<5} {str(instance):<15} {str(cores):<6} {str(ram):<5} {str(ebs_root):<10} {str(ebs_add):<8} {str(os_type):<10}")

print(f"\nTotal registros: {count}")
