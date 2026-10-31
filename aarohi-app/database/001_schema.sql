-- Aarohi SQL Server 2019+ / Azure SQL. Initial migration; no existing database is dropped.
SET NOCOUNT ON; SET XACT_ABORT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
IF OBJECT_ID(N'dbo.SchemaMigration',N'U') IS NOT NULL
BEGIN
 IF EXISTS (SELECT 1 FROM dbo.SchemaMigration WHERE Version='001') BEGIN PRINT '001 already applied'; RETURN; END;
END;
BEGIN TRY
BEGIN TRANSACTION;
IF SCHEMA_ID(N'cfg') IS NULL EXEC(N'CREATE SCHEMA [cfg] AUTHORIZATION dbo');
IF SCHEMA_ID(N'auth') IS NULL EXEC(N'CREATE SCHEMA [auth] AUTHORIZATION dbo');
IF SCHEMA_ID(N'family') IS NULL EXEC(N'CREATE SCHEMA [family] AUTHORIZATION dbo');
IF SCHEMA_ID(N'health') IS NULL EXEC(N'CREATE SCHEMA [health] AUTHORIZATION dbo');
IF SCHEMA_ID(N'food') IS NULL EXEC(N'CREATE SCHEMA [food] AUTHORIZATION dbo');
IF SCHEMA_ID(N'pantry') IS NULL EXEC(N'CREATE SCHEMA [pantry] AUTHORIZATION dbo');
IF SCHEMA_ID(N'notify') IS NULL EXEC(N'CREATE SCHEMA [notify] AUTHORIZATION dbo');
IF SCHEMA_ID(N'commerce') IS NULL EXEC(N'CREATE SCHEMA [commerce] AUTHORIZATION dbo');
IF SCHEMA_ID(N'finance') IS NULL EXEC(N'CREATE SCHEMA [finance] AUTHORIZATION dbo');
IF SCHEMA_ID(N'audit') IS NULL EXEC(N'CREATE SCHEMA [audit] AUTHORIZATION dbo');
IF OBJECT_ID(N'dbo.SchemaMigration',N'U') IS NULL CREATE TABLE dbo.SchemaMigration (Version varchar(20) NOT NULL PRIMARY KEY, AppliedAtUtc datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME());

CREATE TABLE [cfg].[Country] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code char(2) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 CurrencyCode char(3) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[Region] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 CountryId bigint NOT NULL,
 Code varchar(10) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 RegionType varchar(20) NOT NULL CHECK (RegionType IN ('State','UnionTerritory')),
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (CountryId) REFERENCES [cfg].[Country] (Id)
);

CREATE TABLE [cfg].[Cuisine] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 RegionId bigint NOT NULL,
 Code varchar(100) NOT NULL UNIQUE,
 Name nvarchar(150) NOT NULL,
 Description nvarchar(500) NULL,
 SortOrder int NOT NULL DEFAULT 0,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (RegionId) REFERENCES [cfg].[Region] (Id),
 UNIQUE (RegionId,Id)
);

CREATE TABLE [cfg].[Language] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(12) NOT NULL UNIQUE,
 Name nvarchar(80) NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[OptionGroup] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[Option] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 GroupId bigint NOT NULL,
 Code varchar(60) NOT NULL,
 Label nvarchar(150) NOT NULL,
 SortOrder int NOT NULL DEFAULT 0,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (GroupId) REFERENCES [cfg].[OptionGroup] (Id),
 UNIQUE (GroupId,Code)
);

CREATE TABLE [cfg].[Unit] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(20) NOT NULL UNIQUE,
 Name nvarchar(60) NOT NULL,
 Dimension varchar(20) NOT NULL CHECK (Dimension IN ('Mass','Volume','Count','Other')),
 BaseFactor decimal(18,6) NOT NULL CHECK (BaseFactor>0),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[MediaAsset] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(120) NOT NULL UNIQUE,
 StorageProvider varchar(30) NOT NULL,
 StorageKey nvarchar(450) NOT NULL,
 MimeType varchar(80) NOT NULL,
 ByteLength bigint NOT NULL CHECK (ByteLength>=0),
 Sha256 binary(32) NULL,
 AltText nvarchar(500) NOT NULL,
 IsGenerated bit NOT NULL DEFAULT 0,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 UNIQUE (StorageProvider,StorageKey)
);

CREATE TABLE [cfg].[Theme] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(120) NOT NULL,
 TokensJson nvarchar(max) NOT NULL CHECK (ISJSON(TokensJson)=1),
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[Setting] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(120) NOT NULL UNIQUE,
 ValueJson nvarchar(max) NOT NULL CHECK (ISJSON(ValueJson)=1),
 Description nvarchar(500) NOT NULL,
 IsPublic bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [cfg].[Feature] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(100) NOT NULL UNIQUE,
 Name nvarchar(120) NOT NULL,
 IsEnabled bit NOT NULL DEFAULT 0,
 ConfigJson nvarchar(max) NOT NULL DEFAULT N'{}' CHECK (ISJSON(ConfigJson)=1),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[Permission] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(100) NOT NULL UNIQUE,
 Description nvarchar(300) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[Role] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[RolePermission] (
 RoleId bigint NOT NULL,
 PermissionId bigint NOT NULL,
 PRIMARY KEY (RoleId,PermissionId),
 FOREIGN KEY (RoleId) REFERENCES [auth].[Role] (Id),
 FOREIGN KEY (PermissionId) REFERENCES [auth].[Permission] (Id)
);

CREATE TABLE [cfg].[Menu] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(100) NOT NULL UNIQUE,
 ParentId bigint NULL,
 Label nvarchar(100) NOT NULL,
 Route nvarchar(200) NULL,
 IconKey varchar(60) NULL,
 MediaId bigint NULL,
 PermissionId bigint NULL,
 FeatureId bigint NULL,
 SortOrder int NOT NULL DEFAULT 0,
 BackgroundColor varchar(20) NULL,
 ForegroundColor varchar(20) NULL,
 IsVisible bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (ParentId) REFERENCES [cfg].[Menu] (Id),
 FOREIGN KEY (MediaId) REFERENCES [cfg].[MediaAsset] (Id),
 FOREIGN KEY (PermissionId) REFERENCES [auth].[Permission] (Id),
 FOREIGN KEY (FeatureId) REFERENCES [cfg].[Feature] (Id),
 CHECK (ParentId IS NULL OR ParentId<>Id)
);

CREATE TABLE [cfg].[Translation] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 LanguageId bigint NOT NULL,
 ResourceKey varchar(180) NOT NULL,
 Text nvarchar(2000) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (LanguageId) REFERENCES [cfg].[Language] (Id),
 UNIQUE (LanguageId,ResourceKey)
);

CREATE TABLE [auth].[Provider] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Kind varchar(20) NOT NULL CHECK (Kind IN ('OIDC','SMS_OTP','EMAIL_OTP')),
 Name nvarchar(100) NOT NULL,
 Issuer nvarchar(300) NULL,
 ClientId nvarchar(200) NULL,
 SecretReference nvarchar(450) NULL,
 IsEnabled bit NOT NULL DEFAULT 0,
 ConfigJson nvarchar(max) NOT NULL DEFAULT N'{}' CHECK (ISJSON(ConfigJson)=1),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[TokenPolicy] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(50) NOT NULL UNIQUE,
 Issuer nvarchar(300) NOT NULL,
 Audience nvarchar(300) NOT NULL,
 Algorithm varchar(10) NOT NULL CHECK (Algorithm IN ('RS256','ES256')),
 AccessTtlSeconds int NOT NULL CHECK (AccessTtlSeconds BETWEEN 60 AND 3600),
 RefreshTtlDays int NOT NULL CHECK (RefreshTtlDays BETWEEN 1 AND 90),
 ClockSkewSeconds int NOT NULL DEFAULT 30 CHECK (ClockSkewSeconds BETWEEN 0 AND 120),
 SigningKeyReference nvarchar(450) NULL,
 RequireRefreshRotation bit NOT NULL DEFAULT 1,
 IsEnabled bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[UserAccount] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 PublicId uniqueidentifier NOT NULL DEFAULT NEWID() UNIQUE,
 DisplayName nvarchar(120) NOT NULL,
 EmailNormalized nvarchar(254) NULL,
 PhoneE164 varchar(20) NULL,
 EmailVerifiedAt datetime2(3) NULL,
 PhoneVerifiedAt datetime2(3) NULL,
 Status varchar(15) NOT NULL DEFAULT 'Pending' CHECK (Status IN ('Pending','Active','Suspended','Deleted')),
 SecurityStamp uniqueidentifier NOT NULL DEFAULT NEWID(),
 LastLoginAt datetime2(3) NULL,
 DeletedAt datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [auth].[ExternalIdentity] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 UserId bigint NOT NULL,
 ProviderId bigint NOT NULL,
 Subject nvarchar(255) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Issuer nvarchar(300) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (UserId) REFERENCES [auth].[UserAccount] (Id),
 FOREIGN KEY (ProviderId) REFERENCES [auth].[Provider] (Id),
 UNIQUE (ProviderId,Issuer,Subject)
);

CREATE TABLE [auth].[AuthChallenge] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 PublicId uniqueidentifier NOT NULL DEFAULT NEWID() UNIQUE,
 ProviderId bigint NOT NULL,
 UserId bigint NULL,
 Purpose varchar(20) NOT NULL CHECK (Purpose IN ('Login','VerifyContact','Recovery','LinkIdentity')),
 DestinationHmac binary(32) NOT NULL,
 CodeHmac binary(32) NOT NULL,
 HmacKeyVersion varchar(50) NOT NULL,
 ExpiresAt datetime2(3) NOT NULL,
 ConsumedAt datetime2(3) NULL,
 InvalidatedAt datetime2(3) NULL,
 AttemptCount smallint NOT NULL DEFAULT 0,
 MaxAttempts smallint NOT NULL DEFAULT 5 CHECK (MaxAttempts BETWEEN 1 AND 10),
 ResendAfter datetime2(3) NOT NULL,
 RequestKey uniqueidentifier NOT NULL UNIQUE,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (ProviderId) REFERENCES [auth].[Provider] (Id),
 FOREIGN KEY (UserId) REFERENCES [auth].[UserAccount] (Id),
 CHECK (AttemptCount BETWEEN 0 AND MaxAttempts),
 CHECK (ExpiresAt>CreatedAt),
 CHECK (ConsumedAt IS NULL OR ConsumedAt<=ExpiresAt)
);

CREATE TABLE [auth].[Session] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 UserId bigint NOT NULL,
 PublicId uniqueidentifier NOT NULL DEFAULT NEWID() UNIQUE,
 TokenPolicyId bigint NOT NULL,
 DeviceLabel nvarchar(160) NULL,
 ExpiresAt datetime2(3) NOT NULL,
 RevokedAt datetime2(3) NULL,
 RevocationReason nvarchar(200) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (UserId) REFERENCES [auth].[UserAccount] (Id),
 FOREIGN KEY (TokenPolicyId) REFERENCES [auth].[TokenPolicy] (Id),
 CHECK (ExpiresAt>CreatedAt),
 UNIQUE (Id,UserId)
);

CREATE TABLE [auth].[RefreshToken] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 SessionId bigint NOT NULL,
 TokenHash binary(32) NOT NULL UNIQUE,
 ExpiresAt datetime2(3) NOT NULL,
 ConsumedAt datetime2(3) NULL,
 RevokedAt datetime2(3) NULL,
 ParentTokenId bigint NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (SessionId) REFERENCES [auth].[Session] (Id),
 UNIQUE (SessionId,Id),
 FOREIGN KEY (SessionId,ParentTokenId) REFERENCES [auth].[RefreshToken] (SessionId,Id),
 CHECK (ExpiresAt>CreatedAt),
 CHECK (ParentTokenId IS NULL OR ParentTokenId<>Id)
);

CREATE TABLE [auth].[RevokedAccessToken] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 SessionId bigint NOT NULL,
 JtiHash binary(32) NOT NULL UNIQUE,
 ExpiresAt datetime2(3) NOT NULL,
 Reason nvarchar(200) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (SessionId) REFERENCES [auth].[Session] (Id)
);

CREATE TABLE [family].[Household] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 PublicId uniqueidentifier NOT NULL DEFAULT NEWID() UNIQUE,
 Name nvarchar(150) NOT NULL,
 RegionId bigint NOT NULL,
 DefaultCuisineId bigint NOT NULL,
 LanguageId bigint NOT NULL,
 ThemeId bigint NOT NULL,
 City nvarchar(120) NULL,
 PostalCode varchar(12) NULL,
 TimeZoneIana varchar(60) NOT NULL DEFAULT 'Asia/Kolkata',
 CurrencyCode char(3) NOT NULL DEFAULT 'INR',
 Status varchar(15) NOT NULL DEFAULT 'Active' CHECK (Status IN ('Active','Archived')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (RegionId) REFERENCES [cfg].[Region] (Id),
 FOREIGN KEY (RegionId,DefaultCuisineId) REFERENCES [cfg].[Cuisine] (RegionId,Id),
 FOREIGN KEY (LanguageId) REFERENCES [cfg].[Language] (Id),
 FOREIGN KEY (ThemeId) REFERENCES [cfg].[Theme] (Id)
);

CREATE TABLE [family].[Membership] (
 HouseholdId bigint NOT NULL,
 UserId bigint NOT NULL,
 RoleId bigint NOT NULL,
 Status varchar(15) NOT NULL DEFAULT 'Active' CHECK (Status IN ('Invited','Active','Disabled')),
 JoinedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 PRIMARY KEY (HouseholdId,UserId),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (UserId) REFERENCES [auth].[UserAccount] (Id),
 FOREIGN KEY (RoleId) REFERENCES [auth].[Role] (Id)
);

CREATE TABLE [family].[Member] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 Name nvarchar(120) NOT NULL,
 BirthDate date NULL,
 BirthDateIsEstimated bit NOT NULL DEFAULT 0,
 Relationship nvarchar(60) NOT NULL,
 UserId bigint NULL,
 GuardianMemberId bigint NULL,
 DietOptionId bigint NULL,
 AvatarMediaId bigint NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,UserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 FOREIGN KEY (HouseholdId,GuardianMemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (DietOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (AvatarMediaId) REFERENCES [cfg].[MediaAsset] (Id),
 CHECK (GuardianMemberId IS NULL OR GuardianMemberId<>Id)
);

CREATE TABLE [family].[MemberCuisine] (
 HouseholdId bigint NOT NULL,
 MemberId bigint NOT NULL,
 CuisineId bigint NOT NULL,
 Priority smallint NOT NULL DEFAULT 1,
 PRIMARY KEY (HouseholdId,MemberId,CuisineId),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (CuisineId) REFERENCES [cfg].[Cuisine] (Id)
);

CREATE TABLE [family].[MemberAccess] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 UserId bigint NOT NULL,
 PermissionId bigint NOT NULL,
 GrantedByUserId bigint NOT NULL,
 ExpiresAt datetime2(3) NULL,
 RevokedAt datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,UserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 FOREIGN KEY (HouseholdId,GrantedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 FOREIGN KEY (PermissionId) REFERENCES [auth].[Permission] (Id)
);

CREATE TABLE [family].[Consent] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 ActorUserId bigint NOT NULL,
 PurposeCode varchar(100) NOT NULL,
 PolicyVersion varchar(40) NOT NULL,
 GrantedAt datetime2(3) NOT NULL,
 WithdrawnAt datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,ActorUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 CHECK (WithdrawnAt IS NULL OR WithdrawnAt>=GrantedAt)
);

CREATE TABLE [family].[Setting] (
 HouseholdId bigint NOT NULL,
 SettingId bigint NOT NULL,
 ValueJson nvarchar(max) NOT NULL CHECK (ISJSON(ValueJson)=1),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,SettingId),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (SettingId) REFERENCES [cfg].[Setting] (Id)
);

CREATE TABLE [health].[Document] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 CategoryOptionId bigint NOT NULL,
 OriginalName nvarchar(255) NOT NULL,
 StorageKey nvarchar(450) NOT NULL,
 MimeType varchar(80) NOT NULL,
 ByteLength bigint NOT NULL CHECK (ByteLength>0),
 Sha256 binary(32) NULL,
 ScanStatus varchar(20) NOT NULL DEFAULT 'Pending' CHECK (ScanStatus IN ('Pending','Clean','Rejected')),
 ReviewStatus varchar(20) NOT NULL DEFAULT 'Unreviewed' CHECK (ReviewStatus IN ('Unreviewed','Draft','Confirmed','Rejected')),
 UploadedByUserId bigint NOT NULL,
 DocumentDate date NULL,
 DeletedAt datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (CategoryOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (HouseholdId,UploadedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 UNIQUE (HouseholdId,MemberId,Id),
 UNIQUE (StorageKey)
);

CREATE TABLE [health].[DocumentExtraction] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 DocumentId bigint NOT NULL,
 ModelVersion nvarchar(100) NOT NULL,
 ExtractedJson nvarchar(max) NOT NULL CHECK (ISJSON(ExtractedJson)=1),
 ConfirmedByUserId bigint NULL,
 ConfirmedAt datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId,DocumentId) REFERENCES [health].[Document] (HouseholdId,MemberId,Id),
 FOREIGN KEY (HouseholdId,ConfirmedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 CHECK ((ConfirmedAt IS NULL AND ConfirmedByUserId IS NULL) OR (ConfirmedAt IS NOT NULL AND ConfirmedByUserId IS NOT NULL))
);

CREATE TABLE [health].[Condition] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 ConditionOptionId bigint NOT NULL,
 RecordedDate date NOT NULL,
 Notes nvarchar(1000) NULL,
 SourceDocumentId bigint NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (ConditionOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (HouseholdId,MemberId,SourceDocumentId) REFERENCES [health].[Document] (HouseholdId,MemberId,Id)
);

CREATE TABLE [food].[Allergen] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [health].[Allergy] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 AllergenId bigint NOT NULL,
 Reaction nvarchar(500) NULL,
 SeverityOptionId bigint NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (AllergenId) REFERENCES [food].[Allergen] (Id),
 FOREIGN KEY (SeverityOptionId) REFERENCES [cfg].[Option] (Id),
 UNIQUE (HouseholdId,MemberId,AllergenId)
);

CREATE TABLE [health].[DietInstruction] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 Instruction nvarchar(2000) NOT NULL,
 SourceDocumentId bigint NULL,
 AuthorLabel nvarchar(150) NOT NULL,
 ValidFrom date NOT NULL,
 ValidUntil date NULL,
 ReviewStatus varchar(20) NOT NULL DEFAULT 'Unreviewed' CHECK (ReviewStatus IN ('Unreviewed','Approved','Retired')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,MemberId,SourceDocumentId) REFERENCES [health].[Document] (HouseholdId,MemberId,Id),
 CHECK (ValidUntil IS NULL OR ValidUntil>=ValidFrom)
);

CREATE TABLE [health].[Prescription] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 DocumentId bigint NOT NULL,
 PrescribedOn date NOT NULL,
 ValidUntil date NULL,
 ClinicianLabel nvarchar(150) NOT NULL,
 Status varchar(20) NOT NULL DEFAULT 'Unverified' CHECK (Status IN ('Unverified','Verified','Expired','Cancelled')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId,DocumentId) REFERENCES [health].[Document] (HouseholdId,MemberId,Id),
 UNIQUE (HouseholdId,MemberId,Id),
 CHECK (ValidUntil IS NULL OR ValidUntil>=PrescribedOn)
);

CREATE TABLE [health].[PrescriptionItem] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 PrescriptionId bigint NOT NULL,
 MedicineName nvarchar(200) NOT NULL,
 Strength nvarchar(100) NOT NULL,
 FormOptionId bigint NOT NULL,
 Instructions nvarchar(2000) NOT NULL,
 PackDescription nvarchar(150) NULL,
 StartDate date NOT NULL,
 EndDate date NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId,PrescriptionId) REFERENCES [health].[Prescription] (HouseholdId,MemberId,Id),
 FOREIGN KEY (FormOptionId) REFERENCES [cfg].[Option] (Id),
 UNIQUE (HouseholdId,MemberId,Id),
 CHECK (EndDate IS NULL OR EndDate>=StartDate)
);

CREATE TABLE [health].[Observation] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 MetricOptionId bigint NOT NULL,
 ObservedAt datetime2(3) NOT NULL,
 NumericValue decimal(18,4) NULL,
 TextValue nvarchar(1000) NULL,
 UnitId bigint NULL,
 RecordedByUserId bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (MetricOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id),
 FOREIGN KEY (HouseholdId,RecordedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 CHECK (NumericValue IS NOT NULL OR TextValue IS NOT NULL)
);

CREATE TABLE [food].[Ingredient] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(80) NOT NULL UNIQUE,
 Name nvarchar(120) NOT NULL,
 DefaultUnitId bigint NOT NULL,
 MediaId bigint NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (DefaultUnitId) REFERENCES [cfg].[Unit] (Id),
 FOREIGN KEY (MediaId) REFERENCES [cfg].[MediaAsset] (Id)
);

CREATE TABLE [food].[IngredientAllergen] (
 IngredientId bigint NOT NULL,
 AllergenId bigint NOT NULL,
 PRIMARY KEY (IngredientId,AllergenId),
 FOREIGN KEY (IngredientId) REFERENCES [food].[Ingredient] (Id),
 FOREIGN KEY (AllergenId) REFERENCES [food].[Allergen] (Id)
);

CREATE TABLE [food].[Recipe] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(120) NOT NULL UNIQUE,
 Name nvarchar(150) NOT NULL,
 MealTypeOptionId bigint NOT NULL,
 MediaId bigint NOT NULL,
 Servings decimal(8,2) NOT NULL CHECK (Servings>0),
 PrepMinutes smallint NOT NULL CHECK (PrepMinutes>=0),
 IndicativeCostINR decimal(12,2) NULL CHECK (IndicativeCostINR>=0),
 Instructions nvarchar(max) NULL,
 ReviewStatus varchar(20) NOT NULL DEFAULT 'Illustrative' CHECK (ReviewStatus IN ('Illustrative','Reviewed','Retired')),
 IsPlaceholder bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (MealTypeOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (MediaId) REFERENCES [cfg].[MediaAsset] (Id)
);

CREATE TABLE [food].[RecipeCuisine] (
 RecipeId bigint NOT NULL,
 CuisineId bigint NOT NULL,
 SortOrder smallint NOT NULL DEFAULT 0,
 PRIMARY KEY (RecipeId,CuisineId),
 FOREIGN KEY (RecipeId) REFERENCES [food].[Recipe] (Id),
 FOREIGN KEY (CuisineId) REFERENCES [cfg].[Cuisine] (Id)
);

CREATE TABLE [food].[RecipeIngredient] (
 RecipeId bigint NOT NULL,
 IngredientId bigint NOT NULL,
 Quantity decimal(18,4) NOT NULL CHECK (Quantity>0),
 UnitId bigint NOT NULL,
 IsOptional bit NOT NULL DEFAULT 0,
 PRIMARY KEY (RecipeId,IngredientId),
 FOREIGN KEY (RecipeId) REFERENCES [food].[Recipe] (Id),
 FOREIGN KEY (IngredientId) REFERENCES [food].[Ingredient] (Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id)
);

CREATE TABLE [food].[MealPlan] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 RecipeId bigint NOT NULL,
 PlannedDate date NOT NULL,
 LocalTime time(0) NULL,
 Servings decimal(8,2) NOT NULL CHECK (Servings>0),
 Status varchar(15) NOT NULL DEFAULT 'Planned' CHECK (Status IN ('Planned','Prepared','Skipped')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (RecipeId) REFERENCES [food].[Recipe] (Id)
);

CREATE TABLE [pantry].[StockLot] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 IngredientId bigint NOT NULL,
 LotCode nvarchar(80) NOT NULL,
 UnitId bigint NOT NULL,
 PurchasedOn date NULL,
 ExpiresOn date NULL,
 OpenedOn date NULL,
 StorageLocation nvarchar(80) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (IngredientId) REFERENCES [food].[Ingredient] (Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id),
 UNIQUE (HouseholdId,IngredientId,LotCode),
 CHECK (ExpiresOn IS NULL OR PurchasedOn IS NULL OR ExpiresOn>=PurchasedOn)
);

CREATE TABLE [pantry].[Movement] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 StockLotId bigint NOT NULL,
 QuantityDelta decimal(18,4) NOT NULL CHECK (QuantityDelta<>0),
 ReasonOptionId bigint NOT NULL,
 OccurredAt datetime2(3) NOT NULL,
 IdempotencyKey uniqueidentifier NOT NULL,
 RecordedByUserId bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,StockLotId) REFERENCES [pantry].[StockLot] (HouseholdId,Id),
 FOREIGN KEY (ReasonOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (HouseholdId,RecordedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 UNIQUE (HouseholdId,IdempotencyKey)
);

CREATE TABLE [pantry].[AlertRule] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 IngredientId bigint NOT NULL,
 UnitId bigint NOT NULL,
 LowStockQuantity decimal(18,4) NOT NULL CHECK (LowStockQuantity>=0),
 DailyUsageQuantity decimal(18,4) NULL CHECK (DailyUsageQuantity>0),
 RunOutLeadDays smallint NOT NULL CHECK (RunOutLeadDays BETWEEN 0 AND 365),
 ExpiryLeadDays smallint NOT NULL CHECK (ExpiryLeadDays BETWEEN 0 AND 365),
 IsEnabled bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (IngredientId) REFERENCES [food].[Ingredient] (Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id),
 UNIQUE (HouseholdId,IngredientId,UnitId)
);

CREATE TABLE [notify].[Channel] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(40) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 IsEnabled bit NOT NULL DEFAULT 0,
 SecretReference nvarchar(450) NULL,
 ConfigJson nvarchar(max) NOT NULL DEFAULT N'{}' CHECK (ISJSON(ConfigJson)=1),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL
);

CREATE TABLE [notify].[Template] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(80) NOT NULL,
 LanguageId bigint NOT NULL,
 ChannelId bigint NOT NULL,
 Subject nvarchar(200) NULL,
 Body nvarchar(2000) NOT NULL,
 IsEnabled bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (LanguageId) REFERENCES [cfg].[Language] (Id),
 FOREIGN KEY (ChannelId) REFERENCES [notify].[Channel] (Id),
 UNIQUE (Code,LanguageId,ChannelId)
);

CREATE TABLE [notify].[Preference] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 UserId bigint NOT NULL,
 ChannelId bigint NOT NULL,
 IsEnabled bit NOT NULL DEFAULT 0,
 QuietStart time(0) NULL,
 QuietEnd time(0) NULL,
 TimeZoneIana varchar(60) NOT NULL DEFAULT 'Asia/Kolkata',
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,UserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 FOREIGN KEY (ChannelId) REFERENCES [notify].[Channel] (Id),
 UNIQUE (HouseholdId,UserId,ChannelId),
 CHECK ((QuietStart IS NULL AND QuietEnd IS NULL) OR (QuietStart IS NOT NULL AND QuietEnd IS NOT NULL))
);

CREATE TABLE [notify].[Reminder] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NOT NULL,
 KindOptionId bigint NOT NULL,
 PrescriptionItemId bigint NULL,
 Title nvarchar(200) NOT NULL,
 Instructions nvarchar(1000) NULL,
 StartDate date NOT NULL,
 EndDate date NULL,
 TimeZoneIana varchar(60) NOT NULL DEFAULT 'Asia/Kolkata',
 IsEnabled bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (KindOptionId) REFERENCES [cfg].[Option] (Id),
 FOREIGN KEY (HouseholdId,MemberId,PrescriptionItemId) REFERENCES [health].[PrescriptionItem] (HouseholdId,MemberId,Id),
 CHECK (EndDate IS NULL OR EndDate>=StartDate)
);

CREATE TABLE [notify].[ReminderTime] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ReminderId bigint NOT NULL,
 LocalTime time(0) NOT NULL,
 WeekdayMask tinyint NOT NULL CHECK (WeekdayMask BETWEEN 1 AND 127),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ReminderId) REFERENCES [notify].[Reminder] (HouseholdId,Id),
 UNIQUE (HouseholdId,ReminderId,LocalTime)
);

CREATE TABLE [notify].[Occurrence] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ReminderTimeId bigint NOT NULL,
 ScheduledAtUtc datetime2(3) NOT NULL,
 Status varchar(20) NOT NULL DEFAULT 'Pending' CHECK (Status IN ('Pending','Completed','Skipped','Snoozed','Cancelled')),
 CompletedAtUtc datetime2(3) NULL,
 SnoozedUntilUtc datetime2(3) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ReminderTimeId) REFERENCES [notify].[ReminderTime] (HouseholdId,Id),
 UNIQUE (HouseholdId,ReminderTimeId,ScheduledAtUtc),
 CHECK ((Status='Completed' AND CompletedAtUtc IS NOT NULL) OR (Status<>'Completed' AND CompletedAtUtc IS NULL)),
 CHECK ((Status='Snoozed' AND SnoozedUntilUtc IS NOT NULL AND SnoozedUntilUtc>ScheduledAtUtc) OR (Status<>'Snoozed' AND SnoozedUntilUtc IS NULL))
);

CREATE TABLE [notify].[Outbox] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 RecipientUserId bigint NOT NULL,
 TemplateId bigint NOT NULL,
 OccurrenceId bigint NULL,
 DedupeKey varchar(200) NOT NULL,
 PayloadJson nvarchar(max) NOT NULL CHECK (ISJSON(PayloadJson)=1),
 ScheduledAtUtc datetime2(3) NOT NULL,
 Status varchar(15) NOT NULL DEFAULT 'Pending' CHECK (Status IN ('Pending','Leased','Sent','Failed','Cancelled')),
 Attempts smallint NOT NULL DEFAULT 0 CHECK (Attempts>=0),
 LeaseUntilUtc datetime2(3) NULL,
 SentAtUtc datetime2(3) NULL,
 ProviderMessageId nvarchar(200) NULL,
 LastErrorCode varchar(80) NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,RecipientUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 FOREIGN KEY (TemplateId) REFERENCES [notify].[Template] (Id),
 FOREIGN KEY (HouseholdId,OccurrenceId) REFERENCES [notify].[Occurrence] (HouseholdId,Id),
 UNIQUE (HouseholdId,DedupeKey)
);

CREATE TABLE [commerce].[Provider] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(100) NOT NULL,
 Category varchar(20) NOT NULL CHECK (Category IN ('Grocery','Pharmacy')),
 WebsiteUrl nvarchar(300) NOT NULL,
 LogoMediaId bigint NULL,
 ConnectionMode varchar(20) NOT NULL DEFAULT 'WebsiteOnly' CHECK (ConnectionMode IN ('Disabled','WebsiteOnly','PartnerApi')),
 ApiBaseUrl nvarchar(300) NULL,
 SecretReference nvarchar(450) NULL,
 SupportsPriceLookup bit NOT NULL DEFAULT 0,
 SupportsCartTransfer bit NOT NULL DEFAULT 0,
 IsEnabled bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (LogoMediaId) REFERENCES [cfg].[MediaAsset] (Id),
 CHECK (ConnectionMode='PartnerApi' OR (SupportsPriceLookup=0 AND SupportsCartTransfer=0))
);

CREATE TABLE [commerce].[ShoppingList] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 Name nvarchar(150) NOT NULL,
 Kind varchar(20) NOT NULL CHECK (Kind IN ('Grocery','Medicine')),
 Status varchar(15) NOT NULL DEFAULT 'Open' CHECK (Status IN ('Open','Archived')),
 CreatedByUserId bigint NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,CreatedByUserId) REFERENCES [family].[Membership] (HouseholdId,UserId),
 UNIQUE (HouseholdId,Id,Kind)
);

CREATE TABLE [commerce].[ShoppingItem] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ShoppingListId bigint NOT NULL,
 Kind varchar(20) NOT NULL CHECK (Kind IN ('Grocery','Medicine')),
 IngredientId bigint NULL,
 MemberId bigint NULL,
 PrescriptionItemId bigint NULL,
 Description nvarchar(250) NOT NULL,
 Quantity decimal(18,4) NOT NULL CHECK (Quantity>0),
 UnitId bigint NOT NULL,
 Strength nvarchar(100) NULL,
 DosageFormOptionId bigint NULL,
 PackDescription nvarchar(150) NULL,
 IsChecked bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ShoppingListId,Kind) REFERENCES [commerce].[ShoppingList] (HouseholdId,Id,Kind),
 FOREIGN KEY (IngredientId) REFERENCES [food].[Ingredient] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,MemberId,PrescriptionItemId) REFERENCES [health].[PrescriptionItem] (HouseholdId,MemberId,Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id),
 FOREIGN KEY (DosageFormOptionId) REFERENCES [cfg].[Option] (Id),
 CHECK ((Kind='Grocery' AND IngredientId IS NOT NULL AND MemberId IS NULL AND PrescriptionItemId IS NULL) OR (Kind='Medicine' AND IngredientId IS NULL AND MemberId IS NOT NULL AND PrescriptionItemId IS NOT NULL AND Strength IS NOT NULL AND DosageFormOptionId IS NOT NULL AND PackDescription IS NOT NULL)),
 UNIQUE (HouseholdId,ShoppingListId,Id)
);

CREATE TABLE [commerce].[Quote] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ShoppingListId bigint NOT NULL,
 ProviderId bigint NOT NULL,
 PostalCode varchar(12) NOT NULL,
 CurrencyCode char(3) NOT NULL DEFAULT 'INR',
 QuotedAtUtc datetime2(3) NOT NULL,
 ExpiresAtUtc datetime2(3) NOT NULL,
 DeliveryFee decimal(18,2) NOT NULL DEFAULT 0 CHECK (DeliveryFee>=0),
 OtherFees decimal(18,2) NOT NULL DEFAULT 0 CHECK (OtherFees>=0),
 BasketDiscount decimal(18,2) NOT NULL DEFAULT 0 CHECK (BasketDiscount>=0),
 IsDemo bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ShoppingListId) REFERENCES [commerce].[ShoppingList] (HouseholdId,Id),
 FOREIGN KEY (ProviderId) REFERENCES [commerce].[Provider] (Id),
 CHECK (ExpiresAtUtc>QuotedAtUtc),
 UNIQUE (HouseholdId,ShoppingListId,Id)
);

CREATE TABLE [commerce].[QuoteItem] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ShoppingListId bigint NOT NULL,
 QuoteId bigint NOT NULL,
 ShoppingItemId bigint NOT NULL,
 ProviderProductId nvarchar(150) NOT NULL,
 ProductName nvarchar(250) NOT NULL,
 PackQuantity decimal(18,4) NOT NULL CHECK (PackQuantity>0),
 UnitId bigint NOT NULL,
 PackPrice decimal(18,2) NOT NULL CHECK (PackPrice>=0),
 PacksRequired int NOT NULL CHECK (PacksRequired>0),
 Availability varchar(20) NOT NULL CHECK (Availability IN ('Available','Unavailable','Unknown')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ShoppingListId,QuoteId) REFERENCES [commerce].[Quote] (HouseholdId,ShoppingListId,Id),
 FOREIGN KEY (HouseholdId,ShoppingListId,ShoppingItemId) REFERENCES [commerce].[ShoppingItem] (HouseholdId,ShoppingListId,Id),
 FOREIGN KEY (UnitId) REFERENCES [cfg].[Unit] (Id),
 UNIQUE (HouseholdId,QuoteId,ShoppingItemId)
);

CREATE TABLE [commerce].[OrderRecord] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ShoppingListId bigint NOT NULL,
 ProviderId bigint NOT NULL,
 ExternalOrderId nvarchar(150) NULL,
 IdempotencyKey uniqueidentifier NOT NULL,
 Status varchar(20) NOT NULL DEFAULT 'Draft' CHECK (Status IN ('Draft','HandedOff','Confirmed','Delivered','Cancelled','Failed')),
 TotalAmount decimal(18,2) NULL CHECK (TotalAmount>=0),
 CurrencyCode char(3) NOT NULL DEFAULT 'INR',
 ConfirmedAtUtc datetime2(3) NULL,
 IsDemo bit NOT NULL DEFAULT 0,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ShoppingListId) REFERENCES [commerce].[ShoppingList] (HouseholdId,Id),
 FOREIGN KEY (ProviderId) REFERENCES [commerce].[Provider] (Id),
 UNIQUE (HouseholdId,IdempotencyKey)
);

CREATE TABLE [finance].[Category] (
 Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
 Code varchar(60) NOT NULL UNIQUE,
 Name nvarchar(120) NOT NULL,
 Kind varchar(20) NOT NULL CHECK (Kind IN ('Income','Expense','Saving','Asset','Liability')),
 ParentId bigint NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 FOREIGN KEY (ParentId) REFERENCES [finance].[Category] (Id),
 CHECK (ParentId IS NULL OR ParentId<>Id)
);

CREATE TABLE [finance].[Account] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 Name nvarchar(120) NOT NULL,
 TypeOptionId bigint NOT NULL,
 CurrencyCode char(3) NOT NULL DEFAULT 'INR',
 OpeningBalance decimal(18,2) NOT NULL DEFAULT 0,
 OpeningDate date NOT NULL,
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (TypeOptionId) REFERENCES [cfg].[Option] (Id)
);

CREATE TABLE [finance].[IncomePlan] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MemberId bigint NULL,
 CategoryId bigint NOT NULL,
 Name nvarchar(150) NOT NULL,
 MonthlyAmount decimal(18,2) NOT NULL CHECK (MonthlyAmount>=0),
 StartDate date NOT NULL,
 EndDate date NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,MemberId) REFERENCES [family].[Member] (HouseholdId,Id),
 FOREIGN KEY (CategoryId) REFERENCES [finance].[Category] (Id),
 CHECK (EndDate IS NULL OR EndDate>=StartDate)
);

CREATE TABLE [finance].[Budget] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 MonthStart date NOT NULL,
 CategoryId bigint NOT NULL,
 Amount decimal(18,2) NOT NULL CHECK (Amount>=0),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (CategoryId) REFERENCES [finance].[Category] (Id),
 CHECK (DAY(MonthStart)=1),
 UNIQUE (HouseholdId,MonthStart,CategoryId)
);

CREATE TABLE [finance].[TransactionRecord] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 AccountId bigint NOT NULL,
 CategoryId bigint NOT NULL,
 OccurredOn date NOT NULL,
 Description nvarchar(250) NOT NULL,
 Amount decimal(18,2) NOT NULL CHECK (Amount<>0),
 TransferKey uniqueidentifier NULL,
 ExternalReference nvarchar(150) NULL,
 IdempotencyKey uniqueidentifier NOT NULL,
 Status varchar(15) NOT NULL DEFAULT 'Posted' CHECK (Status IN ('Pending','Posted','Voided')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,AccountId) REFERENCES [finance].[Account] (HouseholdId,Id),
 FOREIGN KEY (CategoryId) REFERENCES [finance].[Category] (Id),
 UNIQUE (HouseholdId,IdempotencyKey)
);

CREATE TABLE [finance].[Liability] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 CategoryId bigint NOT NULL,
 Name nvarchar(150) NOT NULL,
 PrincipalOutstanding decimal(18,2) NOT NULL CHECK (PrincipalOutstanding>=0),
 BalanceAsOf date NOT NULL,
 AnnualRatePercent decimal(9,4) NULL CHECK (AnnualRatePercent BETWEEN 0 AND 100),
 MonthlyPayment decimal(18,2) NOT NULL CHECK (MonthlyPayment>=0),
 RemainingMonths int NULL CHECK (RemainingMonths>=0),
 NextDueDate date NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (CategoryId) REFERENCES [finance].[Category] (Id)
);

CREATE TABLE [finance].[Repayment] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 LiabilityId bigint NOT NULL,
 DueDate date NOT NULL,
 AmountDue decimal(18,2) NOT NULL CHECK (AmountDue>=0),
 PaidTransactionId bigint NULL,
 Status varchar(15) NOT NULL DEFAULT 'Scheduled' CHECK (Status IN ('Scheduled','Paid','Missed','Cancelled')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,LiabilityId) REFERENCES [finance].[Liability] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,PaidTransactionId) REFERENCES [finance].[TransactionRecord] (HouseholdId,Id),
 UNIQUE (HouseholdId,LiabilityId,DueDate)
);

CREATE TABLE [finance].[Asset] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 CategoryId bigint NOT NULL,
 Name nvarchar(150) NOT NULL,
 Symbol nvarchar(40) NULL,
 Units decimal(20,6) NULL CHECK (Units>=0),
 CostBasis decimal(18,2) NULL CHECK (CostBasis>=0),
 IsActive bit NOT NULL DEFAULT 1,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (CategoryId) REFERENCES [finance].[Category] (Id)
);

CREATE TABLE [finance].[AssetValuation] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 AssetId bigint NOT NULL,
 ValuationDate date NOT NULL,
 Amount decimal(18,2) NOT NULL CHECK (Amount>=0),
 SourceLabel nvarchar(120) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,AssetId) REFERENCES [finance].[Asset] (HouseholdId,Id),
 UNIQUE (HouseholdId,AssetId,ValuationDate)
);

CREATE TABLE [finance].[ChitPlan] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 Name nvarchar(150) NOT NULL,
 Organizer nvarchar(150) NOT NULL,
 RegistrationReference nvarchar(150) NULL,
 MonthlyContribution decimal(18,2) NOT NULL CHECK (MonthlyContribution>0),
 TenureMonths smallint NOT NULL CHECK (TenureMonths>0),
 StartDate date NOT NULL,
 PayoutReceived decimal(18,2) NOT NULL DEFAULT 0 CHECK (PayoutReceived>=0),
 RemainingObligation decimal(18,2) NOT NULL CHECK (RemainingObligation>=0),
 LinkedLiabilityId bigint NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,LinkedLiabilityId) REFERENCES [finance].[Liability] (HouseholdId,Id)
);

CREATE TABLE [finance].[ChitContribution] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ChitPlanId bigint NOT NULL,
 DueDate date NOT NULL,
 Amount decimal(18,2) NOT NULL CHECK (Amount>0),
 PaidTransactionId bigint NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,ChitPlanId) REFERENCES [finance].[ChitPlan] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,PaidTransactionId) REFERENCES [finance].[TransactionRecord] (HouseholdId,Id),
 UNIQUE (HouseholdId,ChitPlanId,DueDate)
);

CREATE TABLE [finance].[SavingsGoal] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 Name nvarchar(150) NOT NULL,
 TargetAmount decimal(18,2) NOT NULL CHECK (TargetAmount>0),
 MonthlyAllocation decimal(18,2) NOT NULL CHECK (MonthlyAllocation>=0),
 TargetDate date NULL,
 OpeningSavedAmount decimal(18,2) NOT NULL DEFAULT 0 CHECK (OpeningSavedAmount>=0),
 Status varchar(15) NOT NULL DEFAULT 'Active' CHECK (Status IN ('Active','Completed','Paused')),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id)
);

CREATE TABLE [finance].[GoalContribution] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 GoalId bigint NOT NULL,
 ContributedOn date NOT NULL,
 Amount decimal(18,2) NOT NULL CHECK (Amount<>0),
 TransactionId bigint NULL,
 IdempotencyKey uniqueidentifier NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (HouseholdId,GoalId) REFERENCES [finance].[SavingsGoal] (HouseholdId,Id),
 FOREIGN KEY (HouseholdId,TransactionId) REFERENCES [finance].[TransactionRecord] (HouseholdId,Id),
 UNIQUE (HouseholdId,IdempotencyKey)
);

CREATE TABLE [audit].[Event] (
 HouseholdId bigint NOT NULL,
 Id bigint IDENTITY(1,1) NOT NULL,
 ActorUserId bigint NULL,
 ActionCode varchar(100) NOT NULL,
 EntityType varchar(100) NOT NULL,
 EntityKey nvarchar(150) NOT NULL,
 CorrelationId uniqueidentifier NOT NULL,
 Summary nvarchar(500) NOT NULL,
 OccurredAtUtc datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 CreatedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
 Version rowversion NOT NULL,
 PRIMARY KEY (HouseholdId,Id),
 FOREIGN KEY (HouseholdId) REFERENCES [family].[Household] (Id),
 FOREIGN KEY (ActorUserId) REFERENCES [auth].[UserAccount] (Id)
);

CREATE UNIQUE INDEX UX_User_Email ON auth.UserAccount(EmailNormalized) WHERE EmailNormalized IS NOT NULL;
CREATE UNIQUE INDEX UX_User_Phone ON auth.UserAccount(PhoneE164) WHERE PhoneE164 IS NOT NULL;
CREATE UNIQUE INDEX UX_Member_User ON family.Member(HouseholdId,UserId) WHERE UserId IS NOT NULL;
CREATE UNIQUE INDEX UX_Refresh_Child ON auth.RefreshToken(ParentTokenId) WHERE ParentTokenId IS NOT NULL;
CREATE INDEX IX_Challenge_Lookup ON auth.AuthChallenge(DestinationHmac,Purpose,CreatedAt) INCLUDE(AttemptCount,ExpiresAt,ConsumedAt,InvalidatedAt);
CREATE INDEX IX_Session_User ON auth.Session(UserId,ExpiresAt) INCLUDE(RevokedAt);
CREATE INDEX IX_Stock_Expiry ON pantry.StockLot(HouseholdId,ExpiresOn) INCLUDE(IngredientId,UnitId);
CREATE INDEX IX_Movement_Lot ON pantry.Movement(HouseholdId,StockLotId) INCLUDE(QuantityDelta);
CREATE INDEX IX_Reminder_Due ON notify.Occurrence(HouseholdId,Status,ScheduledAtUtc);
CREATE INDEX IX_Outbox_Due ON notify.Outbox(Status,ScheduledAtUtc) INCLUDE(HouseholdId,Attempts,LeaseUntilUtc);
CREATE INDEX IX_Finance_Date ON finance.TransactionRecord(HouseholdId,OccurredOn,CategoryId) INCLUDE(Amount,Status);
CREATE INDEX IX_Health_Member ON health.Observation(HouseholdId,MemberId,ObservedAt);
CREATE INDEX IX_Quote_Expiry ON commerce.Quote(HouseholdId,ShoppingListId,ExpiresAtUtc);
INSERT dbo.SchemaMigration(Version) VALUES('001');
COMMIT;
END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
