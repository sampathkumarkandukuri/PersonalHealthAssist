SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigration WHERE Version='015-app') RETURN;
CREATE TABLE auth.HouseholdInvitation(Id bigint IDENTITY PRIMARY KEY,HouseholdId bigint NOT NULL REFERENCES family.Household(Id),EmailNormalized nvarchar(254) NOT NULL,RoleId bigint NOT NULL REFERENCES auth.Role(Id),TokenHash binary(32) NOT NULL UNIQUE,ExpiresAt datetime2 NOT NULL,ConsumedAt datetime2 NULL,CreatedByUserId bigint NOT NULL REFERENCES auth.UserAccount(Id));
INSERT dbo.SchemaMigration(Version) VALUES('015-app');
