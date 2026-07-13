USE margem_em_risco;
GO

SET NOCOUNT ON;

DECLARE @clients TABLE
(
    client_code VARCHAR(20),
    client_name NVARCHAR(150),
    business_segment VARCHAR(50),
    company_size VARCHAR(20),
    head_office_state CHAR(2),
    region_name VARCHAR(20),
    relationship_start DATE,
    client_status VARCHAR(20)
);

INSERT INTO @clients VALUES
('C001', N'Hospital Vida Central', 'HOSPITAL', 'LARGE', 'SP', 'SOUTHEAST', '2021-01-01', 'ACTIVE'),
('C002', N'Grupo Aurora Offices', 'CORPORATE_OFFICES', 'LARGE', 'SP', 'SOUTHEAST', '2020-06-15', 'ACTIVE'),
('C003', N'RotaSul Logística', 'LOGISTICS', 'LARGE', 'PR', 'SOUTH', '2022-02-01', 'ACTIVE'),
('C004', N'Metalnova Indústria', 'INDUSTRY', 'LARGE', 'MG', 'SOUTHEAST', '2019-08-01', 'ACTIVE'),
('C005', N'Varejo Ponto Certo', 'RETAIL', 'LARGE', 'SP', 'SOUTHEAST', '2023-01-10', 'ACTIVE'),
('C006', N'Condomínio Horizonte', 'BUSINESS_CONDOMINIUM', 'MEDIUM', 'RJ', 'SOUTHEAST', '2022-11-01', 'ACTIVE'),
('C007', N'Instituto Cidadania', 'EDUCATION', 'MEDIUM', 'MG', 'SOUTHEAST', '2024-03-01', 'ACTIVE'),
('C008', N'TechCore Brasil', 'TECHNOLOGY', 'LARGE', 'SP', 'SOUTHEAST', '2021-09-01', 'ACTIVE');

UPDATE target_client
SET
    client_name = source_client.client_name,
    business_segment = source_client.business_segment,
    company_size = source_client.company_size,
    head_office_state = source_client.head_office_state,
    region_name = source_client.region_name,
    relationship_start = source_client.relationship_start,
    client_status = source_client.client_status
FROM dw.dim_client AS target_client
INNER JOIN @clients AS source_client
    ON source_client.client_code = target_client.client_code;

INSERT INTO dw.dim_client
(
    client_code,
    client_name,
    business_segment,
    company_size,
    head_office_state,
    region_name,
    relationship_start,
    client_status
)
SELECT
    source_client.client_code,
    source_client.client_name,
    source_client.business_segment,
    source_client.company_size,
    source_client.head_office_state,
    source_client.region_name,
    source_client.relationship_start,
    source_client.client_status
FROM @clients AS source_client
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_client AS target_client
    WHERE target_client.client_code = source_client.client_code
);

DECLARE @units TABLE
(
    unit_code VARCHAR(20),
    client_code VARCHAR(20),
    unit_name NVARCHAR(150),
    city_name NVARCHAR(100),
    state_code CHAR(2),
    region_name VARCHAR(20),
    facility_type VARCHAR(50),
    approximate_area_m2 DECIMAL(18,2),
    is_24x7_operation BIT,
    criticality_level VARCHAR(20),
    unit_status VARCHAR(20)
);

INSERT INTO @units VALUES
('U001', 'C001', N'Hospital Vida Central - Unidade Principal', N'São Paulo', 'SP', 'SOUTHEAST', 'HOSPITAL', 42000.00, 1, 'ESSENTIAL', 'ACTIVE'),
('U002', 'C002', N'Torre Aurora', N'São Paulo', 'SP', 'SOUTHEAST', 'CORPORATE_TOWER', 28000.00, 0, 'RELEVANT', 'ACTIVE'),
('U003', 'C003', N'Centro de Distribuição Curitiba', N'Curitiba', 'PR', 'SOUTH', 'DISTRIBUTION_CENTER', 36000.00, 1, 'HIGH', 'ACTIVE'),
('U004', 'C004', N'Planta Industrial Contagem', N'Contagem', 'MG', 'SOUTHEAST', 'INDUSTRIAL_PLANT', 51000.00, 1, 'ESSENTIAL', 'ACTIVE'),
('U005', 'C005', N'Operação Regional São Paulo', N'São Paulo', 'SP', 'SOUTHEAST', 'RETAIL_NETWORK', 18000.00, 0, 'HIGH', 'ACTIVE'),
('U006', 'C006', N'Condomínio Empresarial Horizonte', N'Rio de Janeiro', 'RJ', 'SOUTHEAST', 'BUSINESS_CONDOMINIUM', 22000.00, 1, 'RELEVANT', 'ACTIVE'),
('U007', 'C007', N'Campus Belo Horizonte', N'Belo Horizonte', 'MG', 'SOUTHEAST', 'EDUCATION_CAMPUS', 16000.00, 0, 'STANDARD', 'ACTIVE'),
('U008', 'C008', N'TechCore Paulista', N'São Paulo', 'SP', 'SOUTHEAST', 'CORPORATE_OFFICE', 19000.00, 0, 'RELEVANT', 'ACTIVE'),
('U009', 'C008', N'TechCore Alphaville', N'Barueri', 'SP', 'SOUTHEAST', 'CORPORATE_CAMPUS', 31000.00, 1, 'HIGH', 'ACTIVE'),
('U010', 'C008', N'TechCore Data Center', N'Santana de Parnaíba', 'SP', 'SOUTHEAST', 'DATA_CENTER', 26000.00, 1, 'ESSENTIAL', 'ACTIVE');

UPDATE target_unit
SET
    client_key = client.client_key,
    unit_name = source_unit.unit_name,
    city_name = source_unit.city_name,
    state_code = source_unit.state_code,
    region_name = source_unit.region_name,
    facility_type = source_unit.facility_type,
    approximate_area_m2 = source_unit.approximate_area_m2,
    is_24x7_operation = source_unit.is_24x7_operation,
    criticality_level = source_unit.criticality_level,
    unit_status = source_unit.unit_status
FROM dw.dim_unit AS target_unit
INNER JOIN @units AS source_unit
    ON source_unit.unit_code = target_unit.unit_code
INNER JOIN dw.dim_client AS client
    ON client.client_code = source_unit.client_code;

INSERT INTO dw.dim_unit
(
    unit_code,
    client_key,
    unit_name,
    city_name,
    state_code,
    region_name,
    facility_type,
    approximate_area_m2,
    is_24x7_operation,
    criticality_level,
    unit_status
)
SELECT
    source_unit.unit_code,
    client.client_key,
    source_unit.unit_name,
    source_unit.city_name,
    source_unit.state_code,
    source_unit.region_name,
    source_unit.facility_type,
    source_unit.approximate_area_m2,
    source_unit.is_24x7_operation,
    source_unit.criticality_level,
    source_unit.unit_status
FROM @units AS source_unit
INNER JOIN dw.dim_client AS client
    ON client.client_code = source_unit.client_code
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_unit AS target_unit
    WHERE target_unit.unit_code = source_unit.unit_code
);

DECLARE @services TABLE
(
    service_code VARCHAR(20),
    service_name NVARCHAR(80),
    operating_model VARCHAR(50),
    labor_intensity VARCHAR(20),
    complexity_level VARCHAR(20),
    recommended_margin_pct DECIMAL(9,4),
    sla_exposure_level VARCHAR(20),
    requires_full_coverage BIT,
    service_status VARCHAR(20)
);

INSERT INTO @services VALUES
('LIMPEZA', 'Limpeza e conservação', 'POSITION_BASED', 'HIGH', 'MEDIUM', 0.1500, 'MEDIUM', 1, 'ACTIVE'),
('PORTARIA', 'Portaria e controle de acesso', 'POSITION_BASED', 'HIGH', 'MEDIUM', 0.1400, 'HIGH', 1, 'ACTIVE'),
('RECEP', 'Recepção', 'POSITION_BASED', 'HIGH', 'MEDIUM', 0.1500, 'MEDIUM', 1, 'ACTIVE'),
('MANUT', 'Manutenção predial', 'MIXED', 'MEDIUM', 'HIGH', 0.1600, 'HIGH', 1, 'ACTIVE'),
('APOIO', 'Apoio administrativo', 'POSITION_BASED', 'HIGH', 'LOW', 0.1500, 'LOW', 0, 'ACTIVE'),
('FACINT', 'Facilities integrados', 'MIXED', 'HIGH', 'HIGH', 0.1500, 'HIGH', 1, 'ACTIVE');

UPDATE target_service
SET
    service_name = source_service.service_name,
    operating_model = source_service.operating_model,
    labor_intensity = source_service.labor_intensity,
    complexity_level = source_service.complexity_level,
    recommended_margin_pct = source_service.recommended_margin_pct,
    sla_exposure_level = source_service.sla_exposure_level,
    requires_full_coverage = source_service.requires_full_coverage,
    service_status = source_service.service_status
FROM dw.dim_service AS target_service
INNER JOIN @services AS source_service
    ON source_service.service_code = target_service.service_code;

INSERT INTO dw.dim_service
(
    service_code,
    service_name,
    operating_model,
    labor_intensity,
    complexity_level,
    recommended_margin_pct,
    sla_exposure_level,
    requires_full_coverage,
    service_status
)
SELECT *
FROM @services AS source_service
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_service AS target_service
    WHERE target_service.service_code = source_service.service_code
);

DECLARE @roles TABLE
(
    role_code VARCHAR(20),
    role_name NVARCHAR(100),
    role_group VARCHAR(50),
    is_critical_role BIT,
    role_status VARCHAR(20)
);

INSERT INTO @roles VALUES
('AUX_LIMP', 'Auxiliar de limpeza', 'CLEANING', 0, 'ACTIVE'),
('LIDER_LIMP', 'Líder de limpeza', 'CLEANING', 1, 'ACTIVE'),
('PORT', 'Porteiro', 'ACCESS_CONTROL', 1, 'ACTIVE'),
('RECEP', 'Recepcionista', 'RECEPTION', 0, 'ACTIVE'),
('TEC_MANUT', 'Técnico de manutenção', 'MAINTENANCE', 1, 'ACTIVE'),
('SUPERV', 'Supervisor operacional', 'SUPERVISION', 1, 'ACTIVE'),
('ASSIST_ADM', 'Assistente administrativo', 'ADMINISTRATIVE_SUPPORT', 0, 'ACTIVE'),
('ELETRICISTA', 'Eletricista', 'MAINTENANCE', 1, 'ACTIVE'),
('ENCANADOR', 'Encanador', 'MAINTENANCE', 1, 'ACTIVE'),
('JARDINEIRO', 'Jardineiro', 'GROUNDS', 0, 'ACTIVE'),
('CONTROL_ACESSO', 'Controlador de acesso', 'ACCESS_CONTROL', 1, 'ACTIVE'),
('COORD', 'Coordenador de contrato', 'MANAGEMENT', 1, 'ACTIVE');

UPDATE target_role
SET
    role_name = source_role.role_name,
    role_group = source_role.role_group,
    is_critical_role = source_role.is_critical_role,
    role_status = source_role.role_status
FROM dw.dim_role AS target_role
INNER JOIN @roles AS source_role
    ON source_role.role_code = target_role.role_code;

INSERT INTO dw.dim_role
(
    role_code,
    role_name,
    role_group,
    is_critical_role,
    role_status
)
SELECT *
FROM @roles AS source_role
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_role AS target_role
    WHERE target_role.role_code = source_role.role_code
);

DECLARE @managers TABLE
(
    manager_code VARCHAR(20),
    manager_name NVARCHAR(100),
    region_name VARCHAR(20),
    start_date DATE,
    experience_level VARCHAR(20),
    manager_status VARCHAR(20)
);

INSERT INTO @managers VALUES
('G001', N'Mariana Lopes', 'SOUTHEAST', '2020-02-10', 'SENIOR', 'ACTIVE'),
('G002', N'Rafael Nogueira', 'SOUTHEAST', '2021-06-01', 'SENIOR', 'ACTIVE'),
('G003', N'Camila Ferreira', 'SOUTH', '2022-04-18', 'MID', 'ACTIVE'),
('G004', N'Bruno Azevedo', 'SOUTHEAST', '2019-09-02', 'SENIOR', 'ACTIVE'),
('G005', N'Fernanda Reis', 'SOUTHEAST', '2023-01-16', 'MID', 'ACTIVE'),
('G006', N'Lucas Martins', 'SOUTHEAST', '2022-08-08', 'MID', 'ACTIVE'),
('G007', N'Aline Costa', 'SOUTHEAST', '2024-01-08', 'JUNIOR', 'ACTIVE'),
('G008', N'Daniel Ribeiro', 'SOUTHEAST', '2020-11-23', 'SENIOR', 'ACTIVE');

UPDATE target_manager
SET
    manager_name = source_manager.manager_name,
    region_name = source_manager.region_name,
    start_date = source_manager.start_date,
    experience_level = source_manager.experience_level,
    manager_status = source_manager.manager_status
FROM dw.dim_manager AS target_manager
INNER JOIN @managers AS source_manager
    ON source_manager.manager_code = target_manager.manager_code;

INSERT INTO dw.dim_manager
(
    manager_code,
    manager_name,
    region_name,
    start_date,
    experience_level,
    manager_status
)
SELECT *
FROM @managers AS source_manager
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_manager AS target_manager
    WHERE target_manager.manager_code = source_manager.manager_code
);

DECLARE @cost_categories TABLE
(
    cost_group NVARCHAR(60),
    cost_category NVARCHAR(80),
    cost_subcategory NVARCHAR(100),
    is_labor_cost BIT,
    is_controllable_cost BIT,
    category_status VARCHAR(20)
);

INSERT INTO @cost_categories VALUES
('Mão de obra', 'Folha', 'Salários', 1, 0, 'ACTIVE'),
('Mão de obra', 'Encargos', 'Encargos sociais', 1, 0, 'ACTIVE'),
('Mão de obra', 'Benefícios', 'Benefícios', 1, 0, 'ACTIVE'),
('Mão de obra', 'Custos extraordinários', 'Horas adicionais', 1, 1, 'ACTIVE'),
('Mão de obra', 'Cobertura', 'Cobertura emergencial', 1, 1, 'ACTIVE'),
('Operação', 'Materiais', 'Materiais de limpeza', 0, 1, 'ACTIVE'),
('Operação', 'Materiais', 'Materiais administrativos', 0, 1, 'ACTIVE'),
('Operação', 'Equipamentos', 'Manutenção de equipamentos', 0, 1, 'ACTIVE'),
('Operação', 'Transporte', 'Deslocamentos', 0, 1, 'ACTIVE'),
('Operação', 'Supervisão', 'Supervisão de campo', 1, 1, 'ACTIVE'),
('Operação', 'Treinamento', 'Treinamento operacional', 0, 1, 'ACTIVE'),
('Operação', 'Terceiros', 'Serviços terceirizados', 0, 1, 'ACTIVE');

INSERT INTO dw.dim_cost_category
(
    cost_group,
    cost_category,
    cost_subcategory,
    is_labor_cost,
    is_controllable_cost,
    category_status
)
SELECT *
FROM @cost_categories AS source_category
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_cost_category AS target_category
    WHERE target_category.cost_group = source_category.cost_group
      AND target_category.cost_category = source_category.cost_category
      AND target_category.cost_subcategory = source_category.cost_subcategory
);

DECLARE @incident_types TABLE
(
    incident_category NVARCHAR(80),
    incident_subcategory NVARCHAR(100),
    root_cause NVARCHAR(100),
    default_severity VARCHAR(20),
    responsible_area VARCHAR(50),
    has_financial_exposure BIT,
    incident_type_status VARCHAR(20)
);

INSERT INTO @incident_types VALUES
('Cobertura', 'Posto descoberto', 'Absenteísmo', 'HIGH', 'OPERATIONS', 1, 'ACTIVE'),
('Cobertura', 'Atraso na substituição', 'Equipe de cobertura insuficiente', 'CRITICAL', 'OPERATIONS', 1, 'ACTIVE'),
('Qualidade', 'Falha de limpeza', 'Procedimento não seguido', 'MEDIUM', 'QUALITY', 1, 'ACTIVE'),
('Escopo', 'Atividade não prevista', 'Solicitação informal do cliente', 'MEDIUM', 'COMMERCIAL', 1, 'ACTIVE'),
('Manutenção', 'Atraso no atendimento', 'Escala técnica insuficiente', 'CRITICAL', 'OPERATIONS', 1, 'ACTIVE'),
('Manutenção', 'Falha de equipamento', 'Manutenção preventiva atrasada', 'HIGH', 'MAINTENANCE', 1, 'ACTIVE'),
('SLA', 'Prazo não cumprido', 'Falha de supervisão', 'CRITICAL', 'OPERATIONS', 1, 'ACTIVE'),
('Cobertura', 'Posto descoberto', 'Deslocamento entre lojas', 'HIGH', 'OPERATIONS', 1, 'ACTIVE'),
('Atendimento', 'Atraso no atendimento', 'Troca de turno', 'LOW', 'OPERATIONS', 0, 'ACTIVE'),
('Atendimento', 'Solicitação administrativa', 'Demanda pontual', 'LOW', 'OPERATIONS', 0, 'ACTIVE'),
('Atendimento', 'Fila na recepção', 'Pico de visitantes', 'MEDIUM', 'OPERATIONS', 0, 'ACTIVE'),
('Cobertura', 'Posto descoberto', 'Vagas em aberto', 'HIGH', 'PEOPLE', 1, 'ACTIVE'),
('Qualidade', 'Falha de limpeza', 'Equipe incompleta', 'HIGH', 'QUALITY', 1, 'ACTIVE'),
('Manutenção', 'Falha de equipamento', 'Desgaste natural', 'MEDIUM', 'MAINTENANCE', 0, 'ACTIVE'),
('Atendimento', 'Atraso no atendimento', 'Pico operacional', 'LOW', 'OPERATIONS', 0, 'ACTIVE');

INSERT INTO dw.dim_incident_type
(
    incident_category,
    incident_subcategory,
    root_cause,
    default_severity,
    responsible_area,
    has_financial_exposure,
    incident_type_status
)
SELECT *
FROM @incident_types AS source_type
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_incident_type AS target_type
    WHERE target_type.incident_category = source_type.incident_category
      AND target_type.incident_subcategory = source_type.incident_subcategory
      AND target_type.root_cause = source_type.root_cause
);

DECLARE @actions TABLE
(
    action_code VARCHAR(30),
    action_name_pt NVARCHAR(120),
    action_category VARCHAR(50),
    default_owner_area VARCHAR(50),
    action_status VARCHAR(20)
);

INSERT INTO @actions VALUES
('RENEGOTIATE_PRICE', 'Renegociar preço', 'COMMERCIAL', 'COMMERCIAL', 'ACTIVE'),
('REQUEST_ADJUSTMENT', 'Solicitar reajuste', 'COMMERCIAL', 'COMMERCIAL', 'ACTIVE'),
('FORMALIZE_SCOPE', 'Formalizar alteração de escopo', 'COMMERCIAL', 'COMMERCIAL', 'ACTIVE'),
('REVIEW_SCHEDULE', 'Revisar escala', 'OPERATIONS', 'OPERATIONS', 'ACTIVE'),
('REINFORCE_COVERAGE', 'Reforçar cobertura', 'OPERATIONS', 'OPERATIONS', 'ACTIVE'),
('REDUCE_OVERTIME', 'Reduzir horas adicionais', 'OPERATIONS', 'OPERATIONS', 'ACTIVE'),
('SLA_RECOVERY_PLAN', 'Implantar plano de recuperação de SLA', 'QUALITY', 'OPERATIONS', 'ACTIVE'),
('REVIEW_SUPERVISION', 'Revisar supervisão', 'OPERATIONS', 'OPERATIONS', 'ACTIVE'),
('REVIEW_SUPPLIER', 'Revisar fornecedor', 'PROCUREMENT', 'PROCUREMENT', 'ACTIVE'),
('ASSESS_NON_RENEWAL', 'Avaliar não renovação', 'CONTRACT', 'EXECUTIVE', 'ACTIVE'),
('MAINTAIN', 'Manter contrato', 'CONTRACT', 'CONTRACT_MANAGEMENT', 'ACTIVE'),
('EXPAND', 'Avaliar expansão', 'COMMERCIAL', 'COMMERCIAL', 'ACTIVE');

UPDATE target_action
SET
    action_name_pt = source_action.action_name_pt,
    action_category = source_action.action_category,
    default_owner_area = source_action.default_owner_area,
    action_status = source_action.action_status
FROM dw.dim_action AS target_action
INNER JOIN @actions AS source_action
    ON source_action.action_code = target_action.action_code;

INSERT INTO dw.dim_action
(
    action_code,
    action_name_pt,
    action_category,
    default_owner_area,
    action_status
)
SELECT *
FROM @actions AS source_action
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.dim_action AS target_action
    WHERE target_action.action_code = source_action.action_code
);
GO
