#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Genera diagramas de arquitectura .drawio para los ambientes DEV, QA(tst) y STG(uat)
de InteliSrcPA, reflejando el estado real de la IaC, con el estilo del diagrama de PROD.

Arquitectura de estos ambientes (muy distinta de PROD): EC2 standalone (Windows/Linux),
1 RDS SQL Server, AWS Backup, KMS/IAM/Secrets/S3. Sin ALB/ASG/DMS/ACM/FSx activos.

Salida: intelisrcpa-{dev|qa|stg}-infrastructure.drawio en este mismo directorio.
"""
import xml.sax.saxutils as sx

OUTDIR = "/Users/javier.sepulveda/projects/experian/tco-bussines-case/diagramas"

# ---- estilos base (tomados del diagrama de PROD) ----
S_CLOUD = ("points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],"
           "[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;"
           "gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;"
           "pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;"
           "grIcon=mxgraph.aws4.group_aws_cloud_alt;strokeColor=#232F3E;fillColor=none;"
           "verticalAlign=top;align=left;spacingLeft=30;fontColor=#232F3E")
S_VPC = ("points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],"
         "[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;"
         "gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;fontStyle=0;container=1;"
         "pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;"
         "grIcon=mxgraph.aws4.group_vpc2;strokeColor=#8C4FFF;fillColor=none;verticalAlign=top;"
         "align=left;spacingLeft=30;fontColor=#AAB7B8")

def s_group(stroke, font):
    return ("points=[[0,0],[0.25,0],[0.5,0],[0.75,0],[1,0],[1,0.25],[1,0.5],[1,0.75],[1,1],"
            "[0.75,1],[0.5,1],[0.25,1],[0,1],[0,0.75],[0,0.5],[0,0.25]];outlineConnect=0;"
            "gradientColor=none;html=1;whiteSpace=wrap;fontSize=11;fontStyle=0;container=1;"
            "pointerEvents=0;collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;"
            "grIcon=mxgraph.aws4.group_security_group;strokeColor=%s;fillColor=none;"
            "verticalAlign=top;align=left;spacingLeft=30;fontColor=%s") % (stroke, font)

def s_icon(res, fill, fs=9):
    return ("sketch=0;outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;"
            "verticalLabelPosition=top;verticalAlign=bottom;align=center;html=1;fontSize=%d;"
            "aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.%s;"
            "fillColor=%s;labelPosition=center;") % (fs, res, fill)

def s_icon_b(res, fill, fs=9):  # label abajo
    return ("sketch=0;outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;"
            "verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=%d;"
            "aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.%s;"
            "fillColor=%s;") % (fs, res, fill)

S_EBS = ("sketch=0;outlineConnect=0;fontColor=#232F3E;strokeColor=#ffffff;"
         "verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;fontSize=8;"
         "aspect=fixed;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.elastic_block_store;"
         "fillColor=#3F8624")
S_TAG = ("text;html=1;strokeColor=none;fillColor=#FFF2CC;align=center;verticalAlign=middle;"
         "whiteSpace=wrap;rounded=1;fontSize=8;fontColor=#333333;arcSize=50;")
S_NOTE = ("text;html=1;strokeColor=#147EBA;fillColor=#E6F2FF;align=left;verticalAlign=top;"
          "whiteSpace=wrap;overflow=hidden;fontSize=9;fontColor=#333333;rounded=1;arcSize=5;"
          "spacingLeft=5;spacingTop=3;")
S_LEGEND = ("text;html=1;strokeColor=none;fillColor=none;align=left;verticalAlign=top;"
            "whiteSpace=wrap;overflow=hidden;fontSize=9;fontColor=#333333;")
S_ONPREM = ("sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#232F3D;"
            "strokeColor=none;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
            "fontSize=10;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.corporate_data_center;")
S_USERS = ("sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#232F3D;"
           "strokeColor=none;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
           "fontSize=10;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.users;")
S_JENKINS = ("sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#232F3D;"
             "strokeColor=none;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
             "fontSize=10;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.traditional_server;")
S_BACKUP_VAULT = ("sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;fillColor=#7AA116;"
                  "strokeColor=none;verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;"
                  "fontSize=12;aspect=fixed;pointerEvents=1;shape=mxgraph.aws4.backup_vault;")

def esc(s):
    # escape &, <, > and quotes; convert real newlines to XML line-break entity
    out = sx.escape(str(s), {'"': "&quot;", "'": "&apos;"})
    return out.replace("\n", "&#xa;")

class Diagram:
    def __init__(self, dbid, name, w, h):
        self.dbid = dbid; self.name = name; self.w = w; self.h = h
        self.cells = []
    def cell(self, cid, style, value, x, y, w, h, parent="1", vertex=True):
        self.cells.append(
            '        <mxCell id="%s" parent="%s" style="%s" value="%s" vertex="1">\n'
            '          <mxGeometry height="%s" width="%s" x="%s" y="%s" as="geometry" />\n'
            '        </mxCell>' % (cid, parent, style, esc(value), h, w, x, y))
    def edge(self, cid, src, tgt, style, value="", points=None):
        pts = ""
        if points:
            arr = "".join('              <mxPoint x="%s" y="%s" />\n' % (px, py) for px, py in points)
            pts = ('\n          <mxGeometry relative="1" as="geometry">\n'
                   '            <Array as="points">\n%s'
                   '            </Array>\n          </mxGeometry>' % arr)
        else:
            pts = '\n          <mxGeometry relative="1" as="geometry" />'
        self.cells.append(
            '        <mxCell id="%s" parent="1" source="%s" target="%s" style="%s" value="%s" edge="1">%s\n'
            '        </mxCell>' % (cid, src, tgt, style, esc(value), pts))
    def xml(self):
        body = "\n".join(self.cells)
        return ('<mxfile host="Electron" agent="DrawioJSAPI/1.0.0">\n'
                '  <diagram id="%s" name="%s">\n'
                '    <mxGraphModel dx="4200" dy="1200" grid="1" gridSize="10" guides="1" tooltips="1" '
                'connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="%s" pageHeight="%s" '
                'math="0" shadow="0">\n      <root>\n'
                '        <mxCell id="0" />\n        <mxCell id="1" parent="0" />\n'
                '%s\n      </root>\n    </mxGraphModel>\n  </diagram>\n</mxfile>\n'
                % (self.dbid, esc(self.name), self.w, self.h, body))


def build_env(cfg):
    """cfg: dict con toda la definicion del ambiente."""
    d = Diagram(cfg["dbid"], cfg["name"], 1500, 1080)

    # AWS Cloud
    d.cell("aws-cloud", S_CLOUD, cfg["cloud_title"], 50, 30, 1300, 1000)
    # Legend + color legend (dentro de aws-cloud via parent)
    # (se colocan como parent=1 para simplicidad con coords absolutas)
    # VPC
    d.cell("vpc", S_VPC, cfg["vpc_title"], 80, 80, 900, 780)

    # ---- App Tier (Windows) ----
    d.cell("app-tier", s_group("#147EBA", "#147EBA"),
           "Application Tier - Windows (standalone EC2, AD domain-joined) - Private Subnet", 100, 130, 860, 260)
    x = 40
    for i, ins in enumerate(cfg["win"]):
        iid = "win%d" % i
        d.cell(iid, s_icon("ec2", "#ED7100"), ins["label"], x, 60, 50, 50, parent="app-tier")
        d.cell("ebs-%s" % iid, S_EBS, ins["ebs"], x+10, 130, 30, 30, parent="app-tier")
        x += 180
    d.cell("tag-backup-ec2", S_TAG, "tag: backup=yes (all EC2)", 40, 215, 170, 20, parent="app-tier")

    # ---- Linux tier (si aplica) ----
    next_y = 420
    if cfg["linux"]:
        d.cell("linux-tier", s_group("#ED7100", "#ED7100"),
               "Application Tier - Linux (RHEL/Amazon Linux, standalone EC2) - Private Subnet", 100, next_y, 860, 200)
        x = 40
        for i, ins in enumerate(cfg["linux"]):
            iid = "lnx%d" % i
            d.cell(iid, s_icon("ec2", "#ED7100"), ins["label"], x, 55, 50, 50, parent="linux-tier")
            d.cell("ebs-%s" % iid, S_EBS, ins["ebs"], x+10, 125, 30, 30, parent="linux-tier")
            x += 200
        db_y = next_y + 240
    else:
        db_y = next_y

    # ---- DB tier ----
    d.cell("db-tier", s_group("#147EBA", "#147EBA"), "Database Tier - Private Subnet", 100, db_y, 860, 200)
    d.cell("rds", s_icon_b("rds", "#C925D1", 10), cfg["rds_label"], 150, 60, 50, 50, parent="db-tier")
    d.cell("tag-backup-rds", S_TAG, "tag: backup=yes", 170, 130, 100, 20, parent="db-tier")
    d.cell("s3-backup", s_icon_b("s3", "#3F8624"), "S3 RDS Backup\n(KMS Encrypted)", 470, 20, 45, 45, parent="db-tier")
    if cfg["ssis"]:
        d.cell("s3-ssis", s_icon_b("s3", "#3F8624"), "S3 SSIS\n(KMS Encrypted)", 640, 100, 45, 45, parent="db-tier")

    # ---- Security & Operations ----
    d.cell("services-group", s_group("#DD344C", "#DD344C"), "Security and Operations", 1060, 80, 400, 560)
    d.cell("kms", s_icon_b("key_management_service", "#DD344C", 10), cfg["kms_label"], 50, 45, 50, 50, parent="services-group")
    d.cell("iam", s_icon_b("identity_and_access_management", "#DD344C", 10), cfg["iam_label"], 250, 45, 50, 50, parent="services-group")
    d.cell("secrets", s_icon_b("secrets_manager", "#DD344C", 10),
           "Secrets Manager\n(AD credentials for RDS)\nKMS Encrypted", 50, 200, 50, 50, parent="services-group")
    d.cell("ssm", s_icon_b("systems_manager", "#E7157B", 10),
           "SSM\n(SSM Core / Patching\n+ Instance Scheduler)", 250, 200, 50, 50, parent="services-group")

    # ---- AWS Backup ----
    by = db_y + 240
    d.cell("backup-group", s_group("#3F8624", "#3F8624"), "AWS Backup", 80, by, 500, 300)
    d.cell("backup-vault", S_BACKUP_VAULT,
           "Backup Vault\nKMS Encrypted\nLock: min 1d / max 7d", 40, 45, 45, 45, parent="backup-group")
    d.cell("s3-reports", s_icon_b("s3", "#3F8624"), "S3 Backup Reports", 160, 42, 45, 45, parent="backup-group")
    d.cell("backup-plan", ("text;html=1;strokeColor=#3F8624;fillColor=#D5E8D4;align=left;verticalAlign=top;"
                            "whiteSpace=wrap;rounded=1;fontSize=9;fontColor=#333333;spacingLeft=5;spacingTop=3;"),
           ("<b>Backup Plan: Daily</b><br>Schedule: cron(00 22 ? * * *)<br>Start window: 60 min<br>"
            "Completion window: 720 min<br>Retention: 7 days<br>VSS: Enabled (Windows)<br><br>"
            "<b>Selection:</b> tag:backup = yes<br>(EC2 + RDS)"),
           250, 100, 210, 150, parent="backup-group")
    d.cell("backup-report", ("text;html=1;strokeColor=#E7157B;fillColor=#FCE4EC;align=left;verticalAlign=top;"
                              "whiteSpace=wrap;rounded=1;fontSize=9;fontColor=#333333;spacingLeft=5;spacingTop=3;"),
           ("<b>Notifications (SNS):</b><br>Events: BACKUP_JOB_FAILED, BACKUP_JOB_EXPIRED<br>"
            "Email: infra.apc@experian.com<br><br><b>Vault Alarm (CloudWatch):</b><br>"
            "NumberOfBackupJobsAborted"), 40, 110, 200, 130, parent="backup-group")
    d.cell("sns", s_icon_b("sns", "#E7157B"), "SNS Topic\n(Backup Alerts)\nKMS Encrypted", 130, by+280, 45, 45)

    # ---- external actors ----
    d.cell("users", S_USERS, "Internal Users\n(RDP / HTTPS)", -100, 150, 50, 50)
    d.cell("jenkins", S_JENKINS, "Jenkins CI/CD\n10.31.192.0/24", -100, 300, 50, 50)
    d.cell("onprem-ad", S_ONPREM, "On-Premise AD\nena.us.experian.local\nDNS: 10.28.243.113, 10.4.187.170",
           -100, db_y + 60, 50, 50)

    # ---- legend + color legend + notes (parent=1, coords absolutas dentro del cloud) ----
    d.cell("legend", S_LEGEND, cfg["legend"], 560, cfg["legend_y"], 560, 190)
    d.cell("color-legend", S_LEGEND,
           ("<b>Connection Legend:</b><br>"
            "<font color=\"#ED7100\">━━</font> Compute traffic (users/Jenkins to EC2)<br>"
            "<font color=\"#C925D1\">━━</font> Database connections (TCP 1433 / SSRS 8443)<br>"
            "<font color=\"#3F8624\">━━</font> Storage (RDS to S3)<br>"
            "<font color=\"#DD344C\">- - -</font> Security (Secrets/KMS/AD)<br>"
            "<font color=\"#E7157B\">━━</font> Operations (Backup alerts to SNS)<br><br>"
            "<font color=\"#3F8624\">- - -</font> AWS Backup target (tag-based selection)"),
           560, cfg["legend_y"] + 200, 300, 150)

    # ---- edges ----
    win0 = "win0"
    d.edge("e-users-ec2", "users", win0,
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#ED7100;strokeWidth=2;", "HTTPS / RDP")
    d.edge("e-jenkins-ec2", "jenkins", "win%d" % (len(cfg["win"]) - 1),
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#ED7100;strokeWidth=1;dashed=1;", "Deploy")
    # EC2 windows -> RDS
    d.edge("e-ec2-rds", win0, "rds",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#C925D1;strokeWidth=2;", "TCP 1433")
    if cfg["linux"]:
        d.edge("e-lnx-rds", "lnx0", "rds",
               "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#C925D1;strokeWidth=1;", "TCP 1433")
    # RDS -> S3 backup
    d.edge("e-rds-s3", "rds", "s3-backup",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#3F8624;strokeWidth=1;", "Backup/Restore")
    if cfg["ssis"]:
        d.edge("e-rds-ssis", "rds", "s3-ssis",
               "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#3F8624;strokeWidth=1;", "SSIS")
    # RDS -> secrets (AD)
    d.edge("e-rds-secrets", "rds", "secrets",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#DD344C;strokeWidth=1;dashed=1;", "AD Auth")
    # onprem AD -> RDS domain join
    d.edge("e-onprem-rds", "onprem-ad", "rds",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#C925D1;strokeWidth=1;dashed=1;", "AD Domain Join")
    # vault -> sns
    d.edge("e-vault-sns", "backup-vault", "sns",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#E7157B;strokeWidth=1;", "Alerts")
    # backup plan -> tags
    d.edge("e-backup-ec2", "backup-plan", "tag-backup-ec2",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#3F8624;strokeWidth=1;dashed=1;", "Daily Backup")
    d.edge("e-backup-rds", "backup-plan", "tag-backup-rds",
           "edgeStyle=orthogonalEdgeStyle;rounded=1;html=1;strokeColor=#3F8624;strokeWidth=1;dashed=1;", "Daily Backup")

    return d


# =========================== DEFINICIONES POR AMBIENTE ===========================

DEV = {
    "dbid": "intelisrcpa-dev",
    "name": "InteliSrcPA - DEV Environment",
    "file": "intelisrcpa-dev-infrastructure.drawio",
    "cloud_title": "AWS Cloud - us-east-1 (N. Virginia) - InteliSrcPA DEV",
    "vpc_title": "EEC-VPC (Private Subnets)",
    "legend_y": 700,
    "legend": ("<b>InteliSrcPA - DEV Environment</b><br>App ID: 22272 | Owner: Fernando Hidalgo | "
               "CostString: 1741.PA.135.601608<br>Naming: eec-aws-us-eits-intelisrcpa-dev<br><br>"
               "<b>Scheduling:</b> EC2 = br-saopaulo-office-hours<br>"
               "<b>Encryption:</b> All data at rest encrypted with KMS (auto-rotation, 30d deletion window)<br>"
               "<b>RDS:</b> SQL Server 2022 Developer Ed (16), db.m6i.xlarge, 500GB gp3, Single-AZ, BYOL, "
               "force_ssl=1, MAXDOP=2, Backup/Restore to S3<br>"
               "<b>AD Integration:</b> Self-managed AD (ena.us.experian.local) via Secrets Manager<br>"
               "<b>Note:</b> No ALB/ASG/FSx/DMS - standalone EC2 architecture"),
    "win": [
        {"label": "USAEA1DAPWES101\nSSRP (m5.xlarge)\n10.64.74.11", "ebs": "Root: 100GB gp3\nKMS Encrypted"},
        {"label": "USAEA1DWBWES100\nAPI IIS (m5a.large)\n10.64.74.38", "ebs": "Root: 100GB gp3\nKMS Encrypted"},
        {"label": "USAEA1DFSWES102\nWFINT (c5a.xlarge)\n10.64.74.12", "ebs": "Root: 100GB gp3\nKMS Encrypted"},
    ],
    "linux": [],
    "rds_label": ("RDS SQL Server 2022<br>Dev Ed (16) - standalone-02<br>db.m6i.xlarge | 500GB gp3<br>"
                  "Port 1433 | Single-AZ<br>Backup/Restore (S3)<br>Encrypted (KMS)"),
    "ssis": False,
    "kms_label": "KMS Keys\n(EBS + RDS + S3\n+ Backup s3/vault/sns)\nAuto-rotation",
    "iam_label": "IAM Roles\n(EC2 Profile, RDS Monitoring,\nRDS Backup, RDS SSIS, Backup)",
}

QA = {
    "dbid": "intelisrcpa-qa",
    "name": "InteliSrcPA - QA (TST) Environment",
    "file": "intelisrcpa-qa-infrastructure.drawio",
    "cloud_title": "AWS Cloud - us-east-1 (N. Virginia) - InteliSrcPA QA (TST)",
    "vpc_title": "EEC-VPC (Private Subnets)",
    "legend_y": 880,
    "legend": ("<b>InteliSrcPA - QA (TST) Environment</b><br>App ID: 22272 | Owner: Fernando Hidalgo | "
               "CostString: 1741.PA.135.601608<br>Naming: eec-aws-us-eits-intelisrcpa-tst<br><br>"
               "<b>Scheduling:</b> EC2 = us-east-office-hours<br>"
               "<b>Encryption:</b> All data at rest encrypted with KMS (auto-rotation, 30d deletion window)<br>"
               "<b>RDS:</b> SQL Server SE 15, db.r5.large, 200GB gp3, Single-AZ, License-Included, "
               "force_ssl=1, MAXDOP=2, SSIS + SSRS (8443) + Backup/Restore<br>"
               "<b>AD Integration:</b> Self-managed AD (ena.us.experian.local) via Secrets Manager<br>"
               "<b>Note:</b> No ALB/ASG/FSx/DMS - standalone EC2 architecture"),
    "win": [
        {"label": "USAEA1TWBWES200\nWSS web (m5.large)\n10.64.72.140 (+6 IPs)", "ebs": "Root: 100GB + 100GB gp3\nKMS Encrypted"},
        {"label": "USAEA1TFSWES201\nWFINT (c5a.xlarge)\n10.64.72.141", "ebs": "Root: 80GB gp3\nKMS Encrypted"},
    ],
    "linux": [
        {"label": "USAEA1TAPUES202\nBOF (m5.large)\n10.64.72.143", "ebs": "Root: 80GB gp3\nKMS Encrypted"},
    ],
    "rds_label": ("RDS SQL Server SE 15<br>standalone-01<br>db.r5.large | 200GB gp3<br>"
                  "Port 1433 | Single-AZ<br>SSIS + SSRS (8443)<br>Encrypted (KMS)"),
    "ssis": True,
    "kms_label": "KMS Keys\n(EBS + RDS + S3\n+ Backup s3/vault/sns)\nAuto-rotation",
    "iam_label": "IAM Roles\n(EC2 Profile, RDS Monitoring,\nRDS Backup, RDS SSIS, Backup)",
}

STG = {
    "dbid": "intelisrcpa-stg",
    "name": "InteliSrcPA - STG (UAT) Environment",
    "file": "intelisrcpa-stg-infrastructure.drawio",
    "cloud_title": "AWS Cloud - us-east-1 (N. Virginia) - InteliSrcPA STG (UAT)",
    "vpc_title": "EEC-VPC (Private Subnets)",
    "legend_y": 880,
    "legend": ("<b>InteliSrcPA - STG (UAT) Environment</b><br>App ID: 22272 | Owner: Fernando Hidalgo | "
               "CostString: 1741.PA.135.601608<br>Naming: eec-aws-us-eits-intelisrcpa-uat<br><br>"
               "<b>Scheduling:</b> Linux = us-east-office-hours (Windows scheduler off)<br>"
               "<b>Encryption:</b> All data at rest encrypted with KMS (auto-rotation, 30d deletion window)<br>"
               "<b>RDS:</b> SQL Server SE 15, db.r5.large, 200GB gp3, Single-AZ, License-Included, "
               "force_ssl=1, MAXDOP=2, SSIS + SSRS (8443) + Backup/Restore<br>"
               "<b>AD Integration:</b> Self-managed AD (ena.us.experian.local) via Secrets Manager<br>"
               "<b>Note:</b> FSx defined but commented (file server = EC2 FSDSC). No ALB/ASG/DMS/ACM."),
    "win": [
        {"label": "USAEA1UAPWES301\nAPI IIS (m5a.xlarge)\n10.64.74.244", "ebs": "Root: 130GB gp3\nKMS Encrypted"},
        {"label": "USAEA1UFSWES300\nFSDSC file srv (c5a.xl)\n10.64.74.211", "ebs": "Root: 100GB gp3\nKMS Encrypted"},
        {"label": "USAEA1UFSWES302\nWFINT (c5a.xlarge)\n10.64.74.210", "ebs": "Root: 80GB gp3\nKMS Encrypted"},
    ],
    "linux": [
        {"label": "USAEA1UAPUES304\nSTE (c5a.xlarge)\n10.64.74.212", "ebs": "Root: 210GB gp3\nKMS Encrypted"},
        {"label": "USAEA1UAPUES303\nSTS (m5.xlarge)\n10.64.74.215", "ebs": "Root: 520GB gp3\nKMS Encrypted"},
    ],
    "rds_label": ("RDS SQL Server SE 15<br>standalone-01<br>db.r5.large | 200GB gp3<br>"
                  "Port 1433 | Single-AZ<br>SSIS + SSRS (8443)<br>Encrypted (KMS)"),
    "ssis": True,
    "kms_label": "KMS Keys\n(EBS + RDS + S3 + Secret\n+ Backup s3/vault/sns)\nAuto-rotation",
    "iam_label": "IAM Roles\n(EC2 Profile, RDS Monitoring,\nRDS Backup, RDS SSIS,\nDMS VPC, Backup)",
}

for cfg in (DEV, QA, STG):
    d = build_env(cfg)
    out = "%s/%s" % (OUTDIR, cfg["file"])
    with open(out, "w") as f:
        f.write(d.xml())
    print("OK ->", out)
