-- ============================================================================
-- VCI-IAMS Enterprise Dynamic Role-Based Access Control (RBAC) System
-- Database: vciiams
-- Target: MySQL 8.0+ (InnoDB, UTF8mb4)
-- ============================================================================

USE `vciiams`;

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================================
-- 1. TABLE DEFINITIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 Users (Enhanced with Lockout and Security Metadata)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Users` (
    `UserId` INT AUTO_INCREMENT NOT NULL,
    `Username` VARCHAR(50) NOT NULL,
    `Email` VARCHAR(100) NOT NULL,
    `PasswordHash` VARCHAR(255) NOT NULL,
    `PasswordSalt` VARCHAR(255) NOT NULL,
    `FirstName` VARCHAR(50) NOT NULL,
    `LastName` VARCHAR(50) NOT NULL,
    `MiddleName` VARCHAR(50) NULL,
    `DepartmentId` INT NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `IsLocked` BOOLEAN NOT NULL DEFAULT 0,
    `LockoutEnd` DATETIME NULL,
    `LastLoginDate` DATETIME NULL,
    `LastLoginIp` VARCHAR(50) NULL,
    `FailedLoginAttempts` INT NOT NULL DEFAULT 0,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`UserId`),
    UNIQUE KEY `UK_Users_Username` (`Username`),
    UNIQUE KEY `UK_Users_Email` (`Email`),
    INDEX `IX_Users_Status` (`IsActive`, `IsLocked`),
    INDEX `IX_Users_Department` (`DepartmentId`),
    CONSTRAINT `FK_Users_Department` FOREIGN KEY (`DepartmentId`)
        REFERENCES `Departments` (`DepartmentId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- CREATE TABLE IF NOT EXISTS does not upgrade tables from MySQL_Migration.sql.
-- MySQL 8 does not support ADD COLUMN IF NOT EXISTS.
SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'Users' AND column_name = 'LockoutEnd'),
    'SELECT 1',
    'ALTER TABLE `Users` ADD COLUMN `LockoutEnd` DATETIME NULL AFTER `IsLocked`'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'Users' AND column_name = 'LastLoginIp'),
    'SELECT 1',
    'ALTER TABLE `Users` ADD COLUMN `LastLoginIp` VARCHAR(50) NULL AFTER `LastLoginDate`'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 1.2 Roles (Enhanced with RoleCode and IsSystemRole)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `Roles` (
    `RoleId` INT AUTO_INCREMENT NOT NULL,
    `RoleCode` VARCHAR(50) NOT NULL,
    `RoleName` VARCHAR(100) NOT NULL,
    `Description` VARCHAR(255) NULL,
    `IsSystemRole` BOOLEAN NOT NULL DEFAULT 0,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL,
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ModifiedBy` VARCHAR(100) NULL,
    `ModifiedDate` DATETIME NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`RoleId`),
    UNIQUE KEY `UK_Roles_RoleCode` (`RoleCode`),
    UNIQUE KEY `UK_Roles_RoleName` (`RoleName`),
    INDEX `IX_Roles_Active` (`IsActive`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Existing roles need a nullable RoleCode until their codes are populated below.
SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'Roles' AND column_name = 'RoleCode'),
    'SELECT 1',
    'ALTER TABLE `Roles` ADD COLUMN `RoleCode` VARCHAR(50) NULL AFTER `RoleId`'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = IF(
    EXISTS(SELECT 1 FROM information_schema.columns
           WHERE table_schema = DATABASE() AND table_name = 'Roles' AND column_name = 'IsSystemRole'),
    'SELECT 1',
    'ALTER TABLE `Roles` ADD COLUMN `IsSystemRole` BOOLEAN NOT NULL DEFAULT 0 AFTER `Description`'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Materialize missing codes and update by primary key, including in safe update mode.
UPDATE /*+ NO_MERGE(target) */ (
    SELECT `RoleId` FROM `Roles`
    WHERE `RoleCode` IS NULL OR `RoleCode` = ''
) AS target
STRAIGHT_JOIN `Roles` AS r FORCE INDEX (PRIMARY) ON r.`RoleId` = target.`RoleId`
SET r.`RoleCode` = CASE
    WHEN r.`RoleName` = 'Super Admin' THEN 'ADMIN'
    WHEN r.`RoleName` = 'Finance Director' THEN 'FIN_DIR'
    WHEN r.`RoleName` = 'Chief Accountant' THEN 'CHIEF_ACCT'
    WHEN r.`RoleName` = 'Senior Accountant' THEN 'SR_ACCT'
    WHEN r.`RoleName` = 'Junior Accountant' THEN 'JR_ACCT'
    WHEN r.`RoleName` = 'Cashier' THEN 'CASHIER'
    WHEN r.`RoleName` = 'Department Head' THEN 'DEPT_HEAD'
    WHEN r.`RoleName` = 'Auditor' THEN 'AUDITOR'
    ELSE UPPER(REPLACE(r.`RoleName`, ' ', '_'))
END;

-- Add unique index on RoleCode if not present
SET @uk_roles_code_exists = (
    SELECT COUNT(*)
    FROM information_schema.statistics
    WHERE table_schema = DATABASE() AND table_name = 'Roles' AND index_name = 'UK_Roles_RoleCode'
);
SET @sql = IF(@uk_roles_code_exists = 0, 'ALTER TABLE `Roles` ADD UNIQUE KEY `UK_Roles_RoleCode` (`RoleCode`);', 'SELECT 1;');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 1.3 Permissions
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `MenuPermissions`;
DROP TABLE IF EXISTS `RolePermissions`;
DROP TABLE IF EXISTS `UserPermissions`;
DROP TABLE IF EXISTS `Permissions`;

CREATE TABLE `Permissions` (
    `PermissionId` INT AUTO_INCREMENT NOT NULL,
    `PermissionCode` VARCHAR(50) NOT NULL,
    `PermissionName` VARCHAR(100) NOT NULL,
    `Module` VARCHAR(50) NOT NULL,
    `ActionType` VARCHAR(20) NOT NULL DEFAULT 'VIEW',
    `Description` VARCHAR(255) NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`PermissionId`),
    UNIQUE KEY `UK_Permissions_Code` (`PermissionCode`),
    INDEX `IX_Permissions_Module` (`Module`),
    INDEX `IX_Permissions_Action` (`ActionType`),
    INDEX `IX_Permissions_Active` (`IsActive`),
    CONSTRAINT `CHK_Permissions_Action` CHECK (`ActionType` IN ('VIEW', 'CREATE', 'EDIT', 'DELETE', 'POST', 'APPROVE', 'PROCESS', 'ADJUST', 'EXPORT', 'MANAGE'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.4 UserRoles (Mapping Users to Multiple Roles)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `UserRoles`;

CREATE TABLE `UserRoles` (
    `UserRoleId` INT AUTO_INCREMENT NOT NULL,
    `UserId` INT NOT NULL,
    `RoleId` INT NOT NULL,
    `AssignedBy` VARCHAR(100) NOT NULL,
    `AssignedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`UserRoleId`),
    UNIQUE KEY `UK_UserRoles_User_Role` (`UserId`, `RoleId`),
    INDEX `IX_UserRoles_Role` (`RoleId`),
    CONSTRAINT `FK_UserRoles_User` FOREIGN KEY (`UserId`)
        REFERENCES `Users` (`UserId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_UserRoles_Role` FOREIGN KEY (`RoleId`)
        REFERENCES `Roles` (`RoleId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.5 RolePermissions (Mapping Roles to Granular Permissions)
-- ----------------------------------------------------------------------------
CREATE TABLE `RolePermissions` (
    `RolePermissionId` INT AUTO_INCREMENT NOT NULL,
    `RoleId` INT NOT NULL,
    `PermissionId` INT NOT NULL,
    `AssignedBy` VARCHAR(100) NOT NULL,
    `AssignedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`RolePermissionId`),
    UNIQUE KEY `UK_RolePermissions_Role_Perm` (`RoleId`, `PermissionId`),
    INDEX `IX_RolePermissions_Permission` (`PermissionId`),
    CONSTRAINT `FK_RolePermissions_Role` FOREIGN KEY (`RoleId`)
        REFERENCES `Roles` (`RoleId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_RolePermissions_Permission` FOREIGN KEY (`PermissionId`)
        REFERENCES `Permissions` (`PermissionId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.6 UserPermissions (Direct User Permission Overrides: GRANT / REVOKE)
-- ----------------------------------------------------------------------------
CREATE TABLE `UserPermissions` (
    `UserPermissionId` INT AUTO_INCREMENT NOT NULL,
    `UserId` INT NOT NULL,
    `PermissionId` INT NOT NULL,
    `IsGranted` BOOLEAN NOT NULL COMMENT '1 = Explicit GRANT override, 0 = Explicit DENY override',
    `Reason` VARCHAR(255) NULL,
    `ExpiryDate` DATETIME NULL COMMENT 'Optional time-bound override',
    `AssignedBy` VARCHAR(100) NOT NULL,
    `AssignedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`UserPermissionId`),
    UNIQUE KEY `UK_UserPermissions_User_Perm` (`UserId`, `PermissionId`),
    INDEX `IX_UserPermissions_Perm` (`PermissionId`),
    INDEX `IX_UserPermissions_Granted` (`IsGranted`),
    INDEX `IX_UserPermissions_Expiry` (`ExpiryDate`),
    CONSTRAINT `FK_UserPermissions_User` FOREIGN KEY (`UserId`)
        REFERENCES `Users` (`UserId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_UserPermissions_Permission` FOREIGN KEY (`PermissionId`)
        REFERENCES `Permissions` (`PermissionId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.7 Menus (Dynamic Hierarchical Navigation Structure)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS `Menus`;

CREATE TABLE `Menus` (
    `MenuId` INT AUTO_INCREMENT NOT NULL,
    `MenuCode` VARCHAR(50) NOT NULL,
    `Title` VARCHAR(100) NOT NULL,
    `ParentMenuId` INT NULL,
    `RouteUrl` VARCHAR(255) NULL,
    `IconClass` VARCHAR(50) NULL,
    `DisplayOrder` INT NOT NULL DEFAULT 0,
    `Module` VARCHAR(50) NOT NULL,
    `IsActive` BOOLEAN NOT NULL DEFAULT 1,
    `CreatedBy` VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    `CreatedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`MenuId`),
    UNIQUE KEY `UK_Menus_Code` (`MenuCode`),
    INDEX `IX_Menus_Parent` (`ParentMenuId`),
    INDEX `IX_Menus_Module` (`Module`),
    INDEX `IX_Menus_Order` (`DisplayOrder`),
    INDEX `IX_Menus_Active` (`IsActive`),
    CONSTRAINT `FK_Menus_Parent` FOREIGN KEY (`ParentMenuId`)
        REFERENCES `Menus` (`MenuId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.8 MenuPermissions (Linking Menus to Required Securing Permissions)
-- ----------------------------------------------------------------------------
CREATE TABLE `MenuPermissions` (
    `MenuPermissionId` INT AUTO_INCREMENT NOT NULL,
    `MenuId` INT NOT NULL,
    `PermissionId` INT NOT NULL,
    `AssignedBy` VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    `AssignedDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`MenuPermissionId`),
    UNIQUE KEY `UK_MenuPermissions_Menu_Perm` (`MenuId`, `PermissionId`),
    INDEX `IX_MenuPermissions_Permission` (`PermissionId`),
    CONSTRAINT `FK_MenuPermissions_Menu` FOREIGN KEY (`MenuId`)
        REFERENCES `Menus` (`MenuId`) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `FK_MenuPermissions_Permission` FOREIGN KEY (`PermissionId`)
        REFERENCES `Permissions` (`PermissionId`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ----------------------------------------------------------------------------
-- 1.9 AuditLogs (Comprehensive Security, Login & Transaction Auditing)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `AuditLogs` (
    `AuditLogId` BIGINT AUTO_INCREMENT NOT NULL,
    `UserId` INT NULL,
    `Username` VARCHAR(50) NOT NULL,
    `Action` VARCHAR(50) NOT NULL,
    `TableName` VARCHAR(50) NOT NULL,
    `RecordId` VARCHAR(50) NULL,
    `OldValues` LONGTEXT NULL,
    `NewValues` LONGTEXT NULL,
    `IpAddress` VARCHAR(50) NULL,
    `UserAgent` VARCHAR(255) NULL,
    `ActionDate` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`AuditLogId`),
    INDEX `IX_AuditLogs_User` (`UserId`),
    INDEX `IX_AuditLogs_Action` (`Action`),
    INDEX `IX_AuditLogs_Table_Record` (`TableName`, `RecordId`),
    INDEX `IX_AuditLogs_ActionDate` (`ActionDate`),
    CONSTRAINT `FK_AuditLogs_User` FOREIGN KEY (`UserId`)
        REFERENCES `Users` (`UserId`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 2. SCALAR FUNCTIONS & PROCEDURES
-- ============================================================================

DELIMITER $$

-- ----------------------------------------------------------------------------
-- Function: fn_UserHasPermission
-- Evaluates explicit DENY, explicit GRANT, and Role-inherited permissions
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS `fn_UserHasPermission`$$
CREATE FUNCTION `fn_UserHasPermission`(
    p_UserId INT,
    p_PermissionCode VARCHAR(50)
)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE v_PermissionId INT;
    DECLARE v_ExplicitGrant BOOLEAN;
    DECLARE v_RoleGrantCount INT;

    -- 1. Verify permission exists and is active
    SELECT `PermissionId` INTO v_PermissionId
    FROM `Permissions`
    WHERE `PermissionCode` = p_PermissionCode AND `IsActive` = 1
    LIMIT 1;

    IF v_PermissionId IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 2. Check direct UserPermissions override (Explicit DENY = 0 or Explicit GRANT = 1)
    SELECT `IsGranted` INTO v_ExplicitGrant
    FROM `UserPermissions`
    WHERE `UserId` = p_UserId
      AND `PermissionId` = v_PermissionId
      AND (`ExpiryDate` IS NULL OR `ExpiryDate` > NOW())
    LIMIT 1;

    IF v_ExplicitGrant IS NOT NULL THEN
        RETURN v_ExplicitGrant; -- 0 (Explicit Deny) or 1 (Explicit Grant)
    END IF;

    -- 3. Check Role-inherited permissions
    SELECT COUNT(*) INTO v_RoleGrantCount
    FROM `UserRoles` ur
    INNER JOIN `Roles` r ON ur.`RoleId` = r.`RoleId`
    INNER JOIN `RolePermissions` rp ON r.`RoleId` = rp.`RoleId`
    WHERE ur.`UserId` = p_UserId
      AND rp.`PermissionId` = v_PermissionId
      AND r.`IsActive` = 1;

    IF v_RoleGrantCount > 0 THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END$$

-- ----------------------------------------------------------------------------
-- Procedure: sp_AuthenticateUser
-- Secure ERP login authentication & audit logging
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_AuthenticateUser`$$
CREATE PROCEDURE `sp_AuthenticateUser`(
    IN p_Username VARCHAR(50),
    IN p_IpAddress VARCHAR(50),
    IN p_UserAgent VARCHAR(255)
)
BEGIN
    DECLARE v_UserId INT;
    DECLARE v_IsActive BOOLEAN;
    DECLARE v_IsLocked BOOLEAN;
    DECLARE v_LockoutEnd DATETIME;

    SELECT `UserId`, `IsActive`, `IsLocked`, `LockoutEnd`
    INTO v_UserId, v_IsActive, v_IsLocked, v_LockoutEnd
    FROM `Users`
    WHERE `Username` = p_Username
    LIMIT 1;

    -- Check if locked and whether lockout window expired
    IF v_IsLocked = 1 AND v_LockoutEnd IS NOT NULL AND v_LockoutEnd <= NOW() THEN
        UPDATE `Users`
        SET `IsLocked` = 0, `LockoutEnd` = NULL, `FailedLoginAttempts` = 0
        WHERE `UserId` = v_UserId;

        SET v_IsLocked = 0;
    END IF;

    -- Return user profile for verification in application layer
    SELECT
        u.`UserId`,
        u.`Username`,
        u.`Email`,
        u.`PasswordHash`,
        u.`PasswordSalt`,
        u.`FirstName`,
        u.`LastName`,
        u.`DepartmentId`,
        d.`DepartmentName`,
        u.`IsActive`,
        u.`IsLocked`,
        u.`FailedLoginAttempts`
    FROM `Users` u
    LEFT JOIN `Departments` d ON u.`DepartmentId` = d.`DepartmentId`
    WHERE u.`Username` = p_Username;

    -- Return assigned active roles for this user
    SELECT
        r.`RoleId`,
        r.`RoleCode`,
        r.`RoleName`
    FROM `UserRoles` ur
    INNER JOIN `Roles` r ON ur.`RoleId` = r.`RoleId`
    WHERE ur.`UserId` = v_UserId AND r.`IsActive` = 1;
END$$

-- ----------------------------------------------------------------------------
-- Procedure: sp_RecordLoginSuccess
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_RecordLoginSuccess`$$
CREATE PROCEDURE `sp_RecordLoginSuccess`(
    IN p_UserId INT,
    IN p_IpAddress VARCHAR(50),
    IN p_UserAgent VARCHAR(255)
)
BEGIN
    DECLARE v_Username VARCHAR(50);

    SELECT `Username` INTO v_Username FROM `Users` WHERE `UserId` = p_UserId;

    UPDATE `Users`
    SET
        `LastLoginDate` = NOW(),
        `LastLoginIp` = p_IpAddress,
        `FailedLoginAttempts` = 0,
        `IsLocked` = 0,
        `LockoutEnd` = NULL
    WHERE `UserId` = p_UserId;

    INSERT INTO `AuditLogs` (`UserId`, `Username`, `Action`, `TableName`, `RecordId`, `IpAddress`, `UserAgent`, `ActionDate`)
    VALUES (p_UserId, v_Username, 'LOGIN_SUCCESS', 'Users', CAST(p_UserId AS CHAR(50)), p_IpAddress, p_UserAgent, NOW());
END$$

-- ----------------------------------------------------------------------------
-- Procedure: sp_RecordLoginFailure
-- Automatically locks account after 5 failed attempts for 30 minutes
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_RecordLoginFailure`$$
CREATE PROCEDURE `sp_RecordLoginFailure`(
    IN p_Username VARCHAR(50),
    IN p_IpAddress VARCHAR(50),
    IN p_UserAgent VARCHAR(255)
)
BEGIN
    DECLARE v_UserId INT;
    DECLARE v_Attempts INT;

    SELECT `UserId`, `FailedLoginAttempts` + 1
    INTO v_UserId, v_Attempts
    FROM `Users`
    WHERE `Username` = p_Username;

    IF v_UserId IS NOT NULL THEN
        IF v_Attempts >= 5 THEN
            UPDATE `Users`
            SET
                `FailedLoginAttempts` = v_Attempts,
                `IsLocked` = 1,
                `LockoutEnd` = DATE_ADD(NOW(), INTERVAL 30 MINUTE)
            WHERE `UserId` = v_UserId;

            INSERT INTO `AuditLogs` (`UserId`, `Username`, `Action`, `TableName`, `RecordId`, `NewValues`, `IpAddress`, `UserAgent`, `ActionDate`)
            VALUES (v_UserId, p_Username, 'ACCOUNT_LOCKED', 'Users', CAST(v_UserId AS CHAR(50)), 'Exceeded 5 failed attempts; locked for 30 min', p_IpAddress, p_UserAgent, NOW());
        ELSE
            UPDATE `Users`
            SET `FailedLoginAttempts` = v_Attempts
            WHERE `UserId` = v_UserId;

            INSERT INTO `AuditLogs` (`UserId`, `Username`, `Action`, `TableName`, `RecordId`, `NewValues`, `IpAddress`, `UserAgent`, `ActionDate`)
            VALUES (v_UserId, p_Username, 'LOGIN_FAILURE', 'Users', CAST(v_UserId AS CHAR(50)), CONCAT('Attempt: ', v_Attempts), p_IpAddress, p_UserAgent, NOW());
        END IF;
    END IF;
END$$

-- ----------------------------------------------------------------------------
-- Procedure: sp_GetUserEffectivePermissions
-- Returns all effective permissions granted to a given user
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_GetUserEffectivePermissions`$$
CREATE PROCEDURE `sp_GetUserEffectivePermissions`(
    IN p_UserId INT
)
BEGIN
    SELECT
        p.`PermissionId`,
        p.`PermissionCode`,
        p.`PermissionName`,
        p.`Module`,
        p.`ActionType`,
        p.`Description`,
        CASE
            WHEN up.`IsGranted` = 0 THEN 'DENIED_OVERRIDE'
            WHEN up.`IsGranted` = 1 THEN 'GRANTED_OVERRIDE'
            WHEN COUNT(rp.`RoleId`) > 0 THEN 'GRANTED_BY_ROLE'
            ELSE 'NOT_GRANTED'
        END AS `GrantSource`,
        CASE
            WHEN up.`IsGranted` = 0 THEN 0
            WHEN up.`IsGranted` = 1 THEN 1
            WHEN COUNT(rp.`RoleId`) > 0 THEN 1
            ELSE 0
        END AS `IsEffectiveGranted`
    FROM `Permissions` p
    LEFT JOIN `UserPermissions` up ON p.`PermissionId` = up.`PermissionId`
        AND up.`UserId` = p_UserId
        AND (up.`ExpiryDate` IS NULL OR up.`ExpiryDate` > NOW())
    LEFT JOIN `RolePermissions` rp ON p.`PermissionId` = rp.`PermissionId`
        AND rp.`RoleId` IN (
            SELECT ur.`RoleId`
            FROM `UserRoles` ur
            INNER JOIN `Roles` r ON ur.`RoleId` = r.`RoleId`
            WHERE ur.`UserId` = p_UserId AND r.`IsActive` = 1
        )
    WHERE p.`IsActive` = 1
    GROUP BY p.`PermissionId`, p.`PermissionCode`, p.`PermissionName`, p.`Module`, p.`ActionType`, p.`Description`, up.`IsGranted`
    HAVING `IsEffectiveGranted` = 1
    ORDER BY p.`Module`, p.`PermissionCode`;
END$$

-- ----------------------------------------------------------------------------
-- Procedure: sp_GetUserNavigationMenu
-- Dynamic hierarchical menu retrieval filtered by user's effective permissions
-- ----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_GetUserNavigationMenu`$$
CREATE PROCEDURE `sp_GetUserNavigationMenu`(
    IN p_UserId INT
)
BEGIN
    -- Temporary table for effective permissions
    CREATE TEMPORARY TABLE IF NOT EXISTS `_TempUserPerms` (
        `PermissionId` INT PRIMARY KEY
    );
    TRUNCATE TABLE `_TempUserPerms`;

    INSERT INTO `_TempUserPerms` (`PermissionId`)
    SELECT p.`PermissionId`
    FROM `Permissions` p
    LEFT JOIN `UserPermissions` up ON p.`PermissionId` = up.`PermissionId`
        AND up.`UserId` = p_UserId
        AND (up.`ExpiryDate` IS NULL OR up.`ExpiryDate` > NOW())
    LEFT JOIN `RolePermissions` rp ON p.`PermissionId` = rp.`PermissionId`
        AND rp.`RoleId` IN (
            SELECT ur.`RoleId`
            FROM `UserRoles` ur
            INNER JOIN `Roles` r ON ur.`RoleId` = r.`RoleId`
            WHERE ur.`UserId` = p_UserId AND r.`IsActive` = 1
        )
    WHERE p.`IsActive` = 1
    GROUP BY p.`PermissionId`, up.`IsGranted`
    HAVING (
        CASE
            WHEN up.`IsGranted` = 0 THEN 0
            WHEN up.`IsGranted` = 1 THEN 1
            WHEN COUNT(rp.`RoleId`) > 0 THEN 1
            ELSE 0
        END
    ) = 1;

    -- Return all menus that are either:
    -- 1. Unrestricted (no menu permissions required, e.g. Dashboard)
    -- 2. Directly authorized by an effective permission
    -- 3. A parent menu that has at least one authorized child item
    SELECT DISTINCT
        m.`MenuId`,
        m.`MenuCode`,
        m.`Title`,
        m.`ParentMenuId`,
        m.`RouteUrl`,
        m.`IconClass`,
        m.`DisplayOrder`,
        m.`Module`,
        parent.`MenuCode` AS `ParentMenuCode`,
        parent.`Title` AS `ParentTitle`
    FROM `Menus` m
    LEFT JOIN `Menus` parent ON m.`ParentMenuId` = parent.`MenuId`
    LEFT JOIN `MenuPermissions` mp ON m.`MenuId` = mp.`MenuId`
    WHERE m.`IsActive` = 1
      AND (
          -- Option 1: Menu has no permissions assigned (open to all authorized users)
          mp.`PermissionId` IS NULL
          -- Option 2: User has permission mapped to this menu
          OR mp.`PermissionId` IN (SELECT `PermissionId` FROM `_TempUserPerms`)
          -- Option 3: Parent menu having authorized children
          OR m.`MenuId` IN (
              SELECT DISTINCT child.`ParentMenuId`
              FROM `Menus` child
              INNER JOIN `MenuPermissions` child_mp ON child.`MenuId` = child_mp.`MenuId`
              WHERE child_mp.`PermissionId` IN (SELECT `PermissionId` FROM `_TempUserPerms`)
                AND child.`IsActive` = 1
          )
      )
    ORDER BY
        IFNULL(parent.`DisplayOrder`, m.`DisplayOrder`),
        m.`ParentMenuId` IS NOT NULL,
        m.`DisplayOrder`;

    DROP TEMPORARY TABLE IF EXISTS `_TempUserPerms`;
END$$

DELIMITER ;

-- ============================================================================
-- 3. VIEWS FOR SECURITY REPORTING & AUDITING
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: vw_UserSecurityProfile
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_UserSecurityProfile` AS
SELECT
    u.`UserId`,
    u.`Username`,
    u.`Email`,
    CONCAT(u.`FirstName`, ' ', u.`LastName`) AS `FullName`,
    d.`DepartmentName`,
    u.`IsActive`,
    u.`IsLocked`,
    u.`LockoutEnd`,
    u.`LastLoginDate`,
    u.`LastLoginIp`,
    u.`FailedLoginAttempts`,
    GROUP_CONCAT(DISTINCT r.`RoleName` ORDER BY r.`RoleName` SEPARATOR ', ') AS `AssignedRoles`,
    COUNT(DISTINCT ur.`RoleId`) AS `RoleCount`,
    u.`CreatedDate`
FROM `Users` u
LEFT JOIN `Departments` d ON u.`DepartmentId` = d.`DepartmentId`
LEFT JOIN `UserRoles` ur ON u.`UserId` = ur.`UserId`
LEFT JOIN `Roles` r ON ur.`RoleId` = r.`RoleId` AND r.`IsActive` = 1
GROUP BY u.`UserId`, u.`Username`, u.`Email`, u.`FirstName`, u.`LastName`, d.`DepartmentName`,
         u.`IsActive`, u.`IsLocked`, u.`LockoutEnd`, u.`LastLoginDate`, u.`LastLoginIp`, u.`FailedLoginAttempts`, u.`CreatedDate`;

-- ----------------------------------------------------------------------------
-- View: vw_RolePermissionsSummary
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_RolePermissionsSummary` AS
SELECT
    r.`RoleId`,
    r.`RoleCode`,
    r.`RoleName`,
    r.`IsActive` AS `RoleIsActive`,
    p.`Module`,
    p.`PermissionCode`,
    p.`PermissionName`,
    p.`ActionType`,
    rp.`AssignedBy`,
    rp.`AssignedDate`
FROM `Roles` r
INNER JOIN `RolePermissions` rp ON r.`RoleId` = rp.`RoleId`
INNER JOIN `Permissions` p ON rp.`PermissionId` = p.`PermissionId`
WHERE p.`IsActive` = 1;

-- ----------------------------------------------------------------------------
-- View: vw_UserEffectivePermissions
-- Comprehensive matrix of all users, their permissions, and resolution paths
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_UserEffectivePermissions` AS
SELECT
    u.`UserId`,
    u.`Username`,
    CONCAT(u.`FirstName`, ' ', u.`LastName`) AS `FullName`,
    p.`PermissionId`,
    p.`PermissionCode`,
    p.`PermissionName`,
    p.`Module`,
    p.`ActionType`,
    CASE
        WHEN up.`IsGranted` = 0 THEN 'DENIED_BY_OVERRIDE'
        WHEN up.`IsGranted` = 1 THEN 'GRANTED_BY_OVERRIDE'
        WHEN COUNT(rp.`RoleId`) > 0 THEN 'GRANTED_BY_ROLE'
        ELSE 'DENIED'
    END AS `AccessStatus`,
    CASE
        WHEN up.`IsGranted` = 0 THEN 0
        WHEN up.`IsGranted` = 1 THEN 1
        WHEN COUNT(rp.`RoleId`) > 0 THEN 1
        ELSE 0
    END AS `IsEffectiveGranted`,
    up.`Reason` AS `OverrideReason`,
    up.`ExpiryDate` AS `OverrideExpiryDate`
FROM `Users` u
CROSS JOIN `Permissions` p
LEFT JOIN `UserPermissions` up ON u.`UserId` = up.`UserId`
    AND p.`PermissionId` = up.`PermissionId`
    AND (up.`ExpiryDate` IS NULL OR up.`ExpiryDate` > NOW())
LEFT JOIN `RolePermissions` rp ON p.`PermissionId` = rp.`PermissionId`
    AND rp.`RoleId` IN (
        SELECT ur.`RoleId`
        FROM `UserRoles` ur
        INNER JOIN `Roles` r ON ur.`RoleId` = r.`RoleId`
        WHERE ur.`UserId` = u.`UserId` AND r.`IsActive` = 1
    )
WHERE u.`IsActive` = 1 AND p.`IsActive` = 1
GROUP BY u.`UserId`, u.`Username`, u.`FirstName`, u.`LastName`,
         p.`PermissionId`, p.`PermissionCode`, p.`PermissionName`, p.`Module`, p.`ActionType`,
         up.`IsGranted`, up.`Reason`, up.`ExpiryDate`;

-- ----------------------------------------------------------------------------
-- View: vw_SecurityAuditLogReport
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW `vw_SecurityAuditLogReport` AS
SELECT
    al.`AuditLogId`,
    al.`ActionDate`,
    al.`Action`,
    al.`Username`,
    u.`FirstName`,
    u.`LastName`,
    d.`DepartmentName`,
    al.`TableName`,
    al.`RecordId`,
    al.`OldValues`,
    al.`NewValues`,
    al.`IpAddress`,
    al.`UserAgent`
FROM `AuditLogs` al
LEFT JOIN `Users` u ON al.`UserId` = u.`UserId`
LEFT JOIN `Departments` d ON u.`DepartmentId` = d.`DepartmentId`
ORDER BY al.`ActionDate` DESC;

-- ============================================================================
-- 4. MASTER SEED DATA: PERMISSIONS, ROLES, MENUS & MAPPINGS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 Master Permissions (Security, Accounting, Payroll, Inventory, Reports)
-- ----------------------------------------------------------------------------
INSERT INTO `Permissions` (`PermissionCode`, `PermissionName`, `Module`, `ActionType`, `Description`) VALUES
-- Security & System Admin
('USER_VIEW', 'View Users', 'SECURITY', 'VIEW', 'View system users and profiles'),
('USER_CREATE', 'Create Users', 'SECURITY', 'CREATE', 'Create and register new system users'),
('USER_EDIT', 'Edit Users', 'SECURITY', 'EDIT', 'Edit existing user information and security status'),
('USER_DELETE', 'Delete/Deactivate Users', 'SECURITY', 'DELETE', 'Deactivate or lock user accounts'),
('ROLE_VIEW', 'View Roles', 'SECURITY', 'VIEW', 'View role definitions and permissions'),
('ROLE_MANAGE', 'Manage Roles', 'SECURITY', 'MANAGE', 'Create, update, and assign permissions to roles'),
('PERM_VIEW', 'View Permissions', 'SECURITY', 'VIEW', 'View permissions catalog'),
('PERM_MANAGE', 'Manage Permissions', 'SECURITY', 'MANAGE', 'Assign direct user permission overrides'),

-- Accounting & General Ledger
('COA_VIEW', 'View Chart of Accounts', 'ACCOUNTING', 'VIEW', 'View chart of accounts and account balances'),
('COA_CREATE', 'Create Chart of Accounts', 'ACCOUNTING', 'CREATE', 'Create new general ledger accounts'),
('COA_EDIT', 'Edit Chart of Accounts', 'ACCOUNTING', 'EDIT', 'Modify existing general ledger accounts'),
('COA_DELETE', 'Delete Chart of Accounts', 'ACCOUNTING', 'DELETE', 'Deactivate unused general ledger accounts'),
('JE_VIEW', 'View Journal Entries', 'ACCOUNTING', 'VIEW', 'View journal entry vouchers and transaction lines'),
('JE_CREATE', 'Create Journal Entries', 'ACCOUNTING', 'CREATE', 'Draft new double-entry journal vouchers'),
('JE_EDIT', 'Edit Journal Entries', 'ACCOUNTING', 'EDIT', 'Modify unposted draft journal vouchers'),
('JE_POST', 'Post Journal Entries', 'ACCOUNTING', 'POST', 'Post journal entries to general ledger balances'),
('JE_REVERSE', 'Reverse Journal Entries', 'ACCOUNTING', 'POST', 'Create and post reversing journal entries'),
('GL_VIEW', 'View General Ledger', 'ACCOUNTING', 'VIEW', 'View general ledger transaction details and trial balance'),
('PERIOD_CLOSE', 'Close Fiscal Period', 'ACCOUNTING', 'PROCESS', 'Close monthly fiscal periods and lock transactions'),

-- Payroll Module
('EMPLOYEE_VIEW', 'View Employees', 'PAYROLL', 'VIEW', 'View employee roster and personnel records'),
('EMPLOYEE_CREATE', 'Create Employees', 'PAYROLL', 'CREATE', 'Enroll new employees in payroll system'),
('EMPLOYEE_EDIT', 'Edit Employees', 'PAYROLL', 'EDIT', 'Update employee compensation and tax settings'),
('PAYROLL_VIEW', 'View Payroll', 'PAYROLL', 'VIEW', 'View payroll registers and payslips'),
('PAYROLL_PROCESS', 'Process Payroll', 'PAYROLL', 'PROCESS', 'Calculate and generate monthly payroll runs'),
('PAYROLL_APPROVE', 'Approve Payroll', 'PAYROLL', 'APPROVE', 'Authorize payroll disbursements and bank releases'),

-- Inventory Module
('INVENTORY_VIEW', 'View Inventory', 'INVENTORY', 'VIEW', 'View product catalog and stock levels'),
('INVENTORY_CREATE', 'Create Products', 'INVENTORY', 'CREATE', 'Create new inventory items and SKUs'),
('INVENTORY_EDIT', 'Edit Products', 'INVENTORY', 'EDIT', 'Update product details and pricing'),
('INVENTORY_ADJUST', 'Adjust Inventory', 'INVENTORY', 'ADJUST', 'Execute inventory count adjustments and write-offs'),
('STOCK_TRANSFER', 'Stock Transfer', 'INVENTORY', 'PROCESS', 'Transfer stock between departments or warehouses'),

-- Reports Module
('REPORT_VIEW', 'View Reports Portal', 'REPORTS', 'VIEW', 'Access business reporting dashboard'),
('REPORT_FINANCIAL', 'View Financial Statements', 'REPORTS', 'EXPORT', 'Generate Balance Sheet, Income Statement, and Trial Balance'),
('REPORT_PAYROLL', 'View Payroll Reports', 'REPORTS', 'EXPORT', 'Generate payroll summaries and tax withholding reports'),
('REPORT_INVENTORY', 'View Inventory Reports', 'REPORTS', 'EXPORT', 'Generate stock movement and valuation reports')
ON DUPLICATE KEY UPDATE `PermissionName` = VALUES(`PermissionName`), `Description` = VALUES(`Description`);

-- ----------------------------------------------------------------------------
-- 4.2 Standard Enterprise Roles
-- ----------------------------------------------------------------------------
INSERT INTO `Roles` (`RoleCode`, `RoleName`, `Description`, `IsSystemRole`, `IsActive`, `CreatedBy`) VALUES
('ADMIN', 'System Administrator', 'Full system access and security administration', 1, 1, 'SYSTEM'),
('ACCT_MGR', 'Accounting Manager', 'Full management over Chart of Accounts, Journal Entries, and Posting', 0, 1, 'SYSTEM'),
('PAYROLL_CLK', 'Payroll Clerk', 'Employee management and payroll calculation processing', 0, 1, 'SYSTEM'),
('INVENTORY_CLK', 'Inventory Clerk', 'Product catalog maintenance and stock inventory movements', 0, 1, 'SYSTEM')
ON DUPLICATE KEY UPDATE `RoleName` = VALUES(`RoleName`), `Description` = VALUES(`Description`);

-- ----------------------------------------------------------------------------
-- 4.3 Hierarchical Menus
-- ----------------------------------------------------------------------------
INSERT INTO `Menus` (`MenuId`, `MenuCode`, `Title`, `ParentMenuId`, `RouteUrl`, `IconClass`, `DisplayOrder`, `Module`) VALUES
-- Top-Level Root Menus
(1, 'MENU_DASHBOARD', 'Dashboard', NULL, '/', 'bi-speedometer2', 1, 'CORE'),
(2, 'MENU_SECURITY', 'Security', NULL, NULL, 'bi-shield-lock', 2, 'SECURITY'),
(3, 'MENU_ACCOUNTING', 'Accounting', NULL, NULL, 'bi-wallet2', 3, 'ACCOUNTING'),
(4, 'MENU_PAYROLL', 'Payroll', NULL, NULL, 'bi-people', 4, 'PAYROLL'),
(5, 'MENU_INVENTORY', 'Inventory', NULL, NULL, 'bi-boxes', 5, 'INVENTORY'),
(6, 'MENU_REPORTS', 'Reports', NULL, '/Reports', 'bi-bar-chart-line', 6, 'REPORTS'),

-- Sub-Menus: Security
(10, 'MENU_SEC_USERS', 'Users', 2, '/Security/Users', 'bi-person-badge', 1, 'SECURITY'),
(11, 'MENU_SEC_ROLES', 'Roles', 2, '/Security/Roles', 'bi-key', 2, 'SECURITY'),
(12, 'MENU_SEC_PERMS', 'Permissions', 2, '/Security/Permissions', 'bi-sliders', 3, 'SECURITY'),

-- Sub-Menus: Accounting
(20, 'MENU_ACC_COA', 'Chart of Accounts', 3, '/ChartOfAccounts', 'bi-diagram-3', 1, 'ACCOUNTING'),
(21, 'MENU_ACC_JE', 'Journal Entries', 3, '/JournalEntries', 'bi-journal-bookmark', 2, 'ACCOUNTING'),
(22, 'MENU_ACC_GL', 'General Ledger', 3, '/GeneralLedger', 'bi-book', 3, 'ACCOUNTING'),

-- Sub-Menus: Payroll
(30, 'MENU_PAY_EMP', 'Employees', 4, '/Payroll/Employees', 'bi-person-vcard', 1, 'PAYROLL'),
(31, 'MENU_PAY_PROC', 'Payroll Processing', 4, '/Payroll/Process', 'bi-cash-coin', 2, 'PAYROLL'),

-- Sub-Menus: Inventory
(40, 'MENU_INV_PROD', 'Products', 5, '/Inventory/Products', 'bi-box-seam', 1, 'INVENTORY'),
(41, 'MENU_INV_TRANS', 'Stock Transactions', 5, '/Inventory/Transactions', 'bi-arrow-left-right', 2, 'INVENTORY')
ON DUPLICATE KEY UPDATE `Title` = VALUES(`Title`), `RouteUrl` = VALUES(`RouteUrl`), `IconClass` = VALUES(`IconClass`), `DisplayOrder` = VALUES(`DisplayOrder`);

-- ----------------------------------------------------------------------------
-- 4.4 MenuPermissions Mapping (Which permissions unlock which menus)
-- ----------------------------------------------------------------------------
INSERT INTO `MenuPermissions` (`MenuId`, `PermissionId`, `AssignedBy`)
SELECT m.`MenuId`, p.`PermissionId`, 'SYSTEM'
FROM (
    SELECT 'MENU_SEC_USERS' AS MenuCode, 'USER_VIEW' AS PermissionCode UNION ALL
    SELECT 'MENU_SEC_ROLES', 'ROLE_VIEW' UNION ALL
    SELECT 'MENU_SEC_PERMS', 'PERM_VIEW' UNION ALL
    SELECT 'MENU_ACC_COA', 'COA_VIEW' UNION ALL
    SELECT 'MENU_ACC_JE', 'JE_VIEW' UNION ALL
    SELECT 'MENU_ACC_GL', 'GL_VIEW' UNION ALL
    SELECT 'MENU_PAY_EMP', 'EMPLOYEE_VIEW' UNION ALL
    SELECT 'MENU_PAY_PROC', 'PAYROLL_VIEW' UNION ALL
    SELECT 'MENU_INV_PROD', 'INVENTORY_VIEW' UNION ALL
    SELECT 'MENU_INV_TRANS', 'INVENTORY_VIEW' UNION ALL
    SELECT 'MENU_REPORTS', 'REPORT_VIEW'
) mapping
INNER JOIN `Menus` m ON mapping.MenuCode = m.MenuCode
INNER JOIN `Permissions` p ON mapping.PermissionCode = p.PermissionCode
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- ----------------------------------------------------------------------------
-- 4.5 RolePermissions Assignments
-- ----------------------------------------------------------------------------

-- Role 1: System Administrator (ALL Permissions)
INSERT INTO `RolePermissions` (`RoleId`, `PermissionId`, `AssignedBy`)
SELECT r.`RoleId`, p.`PermissionId`, 'SYSTEM'
FROM `Roles` r
CROSS JOIN `Permissions` p
WHERE r.`RoleCode` = 'ADMIN'
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- Role 2: Accounting Manager
INSERT INTO `RolePermissions` (`RoleId`, `PermissionId`, `AssignedBy`)
SELECT r.`RoleId`, p.`PermissionId`, 'SYSTEM'
FROM `Roles` r
CROSS JOIN `Permissions` p
WHERE r.`RoleCode` = 'ACCT_MGR'
  AND p.`PermissionCode` IN (
      'COA_VIEW', 'COA_CREATE', 'COA_EDIT', 'COA_DELETE',
      'JE_VIEW', 'JE_CREATE', 'JE_EDIT', 'JE_POST', 'JE_REVERSE',
      'GL_VIEW', 'PERIOD_CLOSE',
      'REPORT_VIEW', 'REPORT_FINANCIAL'
  )
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- Role 3: Payroll Clerk
INSERT INTO `RolePermissions` (`RoleId`, `PermissionId`, `AssignedBy`)
SELECT r.`RoleId`, p.`PermissionId`, 'SYSTEM'
FROM `Roles` r
CROSS JOIN `Permissions` p
WHERE r.`RoleCode` = 'PAYROLL_CLK'
  AND p.`PermissionCode` IN (
      'EMPLOYEE_VIEW', 'EMPLOYEE_CREATE', 'EMPLOYEE_EDIT',
      'PAYROLL_VIEW', 'PAYROLL_PROCESS',
      'REPORT_VIEW', 'REPORT_PAYROLL'
  )
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- Role 4: Inventory Clerk
INSERT INTO `RolePermissions` (`RoleId`, `PermissionId`, `AssignedBy`)
SELECT r.`RoleId`, p.`PermissionId`, 'SYSTEM'
FROM `Roles` r
CROSS JOIN `Permissions` p
WHERE r.`RoleCode` = 'INVENTORY_CLK'
  AND p.`PermissionCode` IN (
      'INVENTORY_VIEW', 'INVENTORY_CREATE', 'INVENTORY_EDIT',
      'INVENTORY_ADJUST', 'STOCK_TRANSFER',
      'REPORT_VIEW', 'REPORT_INVENTORY'
  )
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);

-- ----------------------------------------------------------------------------
-- 4.6 Assign Administrator Role to Default Admin User
-- ----------------------------------------------------------------------------
INSERT INTO `UserRoles` (`UserId`, `RoleId`, `AssignedBy`)
SELECT u.`UserId`, r.`RoleId`, 'SYSTEM'
FROM `Users` u
CROSS JOIN `Roles` r
WHERE u.`Username` = 'admin' AND r.`RoleCode` = 'ADMIN'
ON DUPLICATE KEY UPDATE `AssignedBy` = VALUES(`AssignedBy`);
