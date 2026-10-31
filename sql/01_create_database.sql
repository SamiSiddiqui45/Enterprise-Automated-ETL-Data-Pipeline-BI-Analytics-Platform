-- ============================================================================
-- Script: 01_create_database.sql
-- Project: Enterprise Automated ETL Data Pipeline & Interactive BI Analytics Platform
-- Purpose: Safely create AnalyticsDW database if it does not exist
-- Author: Senior Data Engineer & Database Architect
-- ============================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'AnalyticsDW')
BEGIN
    PRINT 'Creating database AnalyticsDW...';
    CREATE DATABASE AnalyticsDW
    COLLATE SQL_Latin1_General_CP1_CI_AS;
    PRINT 'Database AnalyticsDW created successfully.';
END
ELSE
BEGIN
    PRINT 'Database AnalyticsDW already exists. Skipping creation to protect existing state.';
END
GO
