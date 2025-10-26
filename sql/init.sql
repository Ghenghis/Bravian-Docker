-- Docker Travian Database Initialization
-- This file initializes the basic database structure for the Travian game server

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS `travian` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `travian`;

-- Basic users table
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL UNIQUE,
  `email` varchar(100) NOT NULL UNIQUE,
  `password_hash` varchar(255) NOT NULL,
  `tribe` tinyint(1) NOT NULL DEFAULT '1',
  `gold` int(11) NOT NULL DEFAULT '0',
  `last_login` timestamp NULL DEFAULT NULL,
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_username` (`username`),
  KEY `idx_email` (`email`),
  KEY `idx_last_login` (`last_login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Basic villages table
CREATE TABLE IF NOT EXISTS `villages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `owner_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `x_coord` int(11) NOT NULL,
  `y_coord` int(11) NOT NULL,
  `population` int(11) NOT NULL DEFAULT '0',
  `loyalty` int(11) NOT NULL DEFAULT '100',
  `capital` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_owner_id` (`owner_id`),
  KEY `idx_coordinates` (`x_coord`, `y_coord`),
  KEY `idx_population` (`population`),
  FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Basic buildings table
CREATE TABLE IF NOT EXISTS `buildings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `village_id` int(11) NOT NULL,
  `type` tinyint(2) NOT NULL,
  `level` tinyint(2) NOT NULL DEFAULT '0',
  `complete_time` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_village_id` (`village_id`),
  KEY `idx_type` (`type`),
  KEY `idx_level` (`level`),
  FOREIGN KEY (`village_id`) REFERENCES `villages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Basic resources table
CREATE TABLE IF NOT EXISTS `resources` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `village_id` int(11) NOT NULL,
  `wood` decimal(10,2) NOT NULL DEFAULT '0.00',
  `clay` decimal(10,2) NOT NULL DEFAULT '0.00',
  `iron` decimal(10,2) NOT NULL DEFAULT '0.00',
  `crop` decimal(10,2) NOT NULL DEFAULT '0.00',
  `last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idx_village_id` (`village_id`),
  KEY `idx_last_update` (`last_update`),
  FOREIGN KEY (`village_id`) REFERENCES `villages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default admin user (password: admin123)
INSERT IGNORE INTO `users` (`id`, `username`, `email`, `password_hash`, `tribe`, `gold`, `active`) VALUES
(1, 'admin', 'admin@bravian-docker.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 1, 1000, 1);

-- Create default village for admin
INSERT IGNORE INTO `villages` (`id`, `owner_id`, `name`, `x_coord`, `y_coord`, `population`, `capital`) VALUES
(1, 1, 'Capital', 0, 0, 100, 1);

-- Initialize resources for default village
INSERT IGNORE INTO `resources` (`village_id`, `wood`, `clay`, `iron`, `crop`) VALUES
(1, 1000.00, 1000.00, 1000.00, 1000.00);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS `idx_users_active` ON `users` (`active`);
CREATE INDEX IF NOT EXISTS `idx_villages_coords` ON `villages` (`x_coord`, `y_coord`);
CREATE INDEX IF NOT EXISTS `idx_buildings_village_type` ON `buildings` (`village_id`, `type`);

COMMIT;
