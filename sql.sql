-- Create kitchens table
CREATE TABLE IF NOT EXISTS `kitchens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `job` varchar(50) NOT NULL,
  `polyzone` text DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create kitchen_stations table
CREATE TABLE IF NOT EXISTS `kitchen_stations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kitchen_id` int(11) NOT NULL,
  `type` varchar(50) NOT NULL,
  `coords` text NOT NULL,
  `heading` float NOT NULL,
  PRIMARY KEY (`id`),
  KEY `kitchen_id` (`kitchen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Create kitchen_recipes table
CREATE TABLE IF NOT EXISTS `kitchen_recipes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kitchen_id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `is_food` tinyint(1) DEFAULT 0,
  `is_drink` tinyint(1) DEFAULT 0,
  `station_type` varchar(50) NOT NULL,
  `ingredients` text NOT NULL,
  `output_amount` int(11) DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `kitchen_id` (`kitchen_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert Burgershot kitchen
INSERT INTO `kitchens` (`name`, `job`, `polyzone`) VALUES 
('Burgershot', 'burgershot', NULL);
