/*
Author : Sandeep Kumar.Sangineedy
Email: sangineedy@gmail.com

Title: Multidimensional SQL Instance Database Size Analysis
Abstract : Summarized analysis of all ONLINE Database capacity that are hosted on SQL Server Instance

Compatible & Tested SQL Versions: 2008, 2008 R2, 2012, 2014, 2016  & 2017
 
Usage:  
1. Open SQL Server Management Studio (SSMS) and connect to SQL Server. 
2. Click on “New Query”, copy the complete code and, paste it and run (Complete code). 
3. Enter the Perameter values for below variable
 
	@Search_Database_Name = '%'
	
Purpose: Detailed breakup analyze of all online SQL Server database size information in multidimensional way (Below mentioned dimentions)

		1. Server and SQL Instance Information
		2. All Databases Total Size summary (Server wise)
		3. DB Files residing drive size summary (Drive wise)
		4. All Databases Total Size summary (Individual DB wise)
		5. Individual File group summary
		6. Individual File Path summary
		7. Individual database File summary
			
What does this script reads?

This Script reads below information from individual SQL Server databases and performs server  wise detailed analysis and displays result 

		************  SQL Instance Level  ************
		1.	[ master.dbo.xp_regread ]  ( For reading actual server name )
		2.	[ xp_msver ]
		3.	[ dm_os_sys_info ]
		4.	[ sys.databases ]
		5.  [ sys.master_files ]
		6.  [ sys.dm_os_volume_stats ]
		
		************  Every Online Database  ************
		5.	 [ sysfiles ]
		6.	[ filegroups ]
		
*/

BEGIN

SET NOCOUNT ON

DECLARE	 @Domain_Name VARCHAR(400)
		,@OS_Name VARCHAR(4000)
		,@SQL_Version VARCHAR(50)
		,@SQLCMD VARCHAR(2000)
		,@CPU_Count INT
		,@Search_Database_Name VARCHAR(4000)
		,@iCount INT
		,@iTotal INT
		,@RegValue NVARCHAR(100)
		,@TotalSizeDB NUMERIC(38,3)
		,@RAMSize NUMERIC(10,3)
		,@DBName varchar(1000)
		,@DBId int
		,@Total_Size NUMERIC(38,3)
		,@Total_Data_Size NUMERIC(30,3)
		,@Total_Log_Size NUMERIC(30,3)
		

		SELECT @Search_Database_Name = '%'


	IF OBJECT_ID('tempdb..#Complete_Info','U') IS NOT NULL
		DROP TABLE #Complete_Info
	
		CREATE TABLE #Complete_Info(
			DB_ID1 NUMERIC(10,0),
			Recovery_Model VARCHAR(20),
			DBname VARCHAR(2000),
			DB_Owner VARCHAR(500),
			LName VARCHAR(200),
			PName VARCHAR(700),
			size NUMERIC(38,3),
			usedspace NUMERIC(38,3),
			freespace NUMERIC(38,3),
			File_Type VARCHAR(20),
			[File_Growth] BIGINT,
			[Max_File_Size] BIGINT,
			Groupname VARCHAR(1000))			


		DECLARE @MSVER TABLE(
			[index] int, 
			name sysname,
			internal_value int,
			character_value varchar(30))

		DECLARE @Total_Size_Summary	TABLE(
			Weightage NUMERIC(30,3),
			Database_ID INT,
			Database_Name VARCHAR(4000),
			DB_Files_Count INT,
			Used_Size NUMERIC(38,3),
			Free_Size NUMERIC(38,3),
			Total_Size NUMERIC(38,3),
			Data_Size NUMERIC(38,3),
			Log_Size NUMERIC(38,3))

		DECLARE	@Drive_DB_Info TABLE(
			Drive_Letter VARCHAR(10),
			Drive_Label VARCHAR(500),
			No_of_Files INT,
			Drive_Total_Size_MB NUMERIC(38,3),
			Drive_Used_Size_MB NUMERIC(38,3),
			Drive_Free_Size_MB NUMERIC(38,3),
			DB_Total_Size NUMERIC(38,3),
			DB_Used_Size NUMERIC(38,3),
			DB_Free_Size NUMERIC(38,3),
			Non_DB_Size NUMERIC(38,3))

		DECLARE @Files_Wise_Analysis TABLE(
			Database_Name VARCHAR(4000),
			File_Location VARCHAR(4000),
			File_Type VARCHAR(200),
			No_of_Files INT,
			Total_Size NUMERIC(38,3),
			Used_Size NUMERIC(38,3),
			Free_Size NUMERIC(38,3))

		DECLARE @File_Group_Analysis TABLE(
			Database_Name VARCHAR(4000),
			File_Group VARCHAR(4000),
			No_of_Files INT,
			Total_Size NUMERIC(38,3),
			Used_Size NUMERIC(38,3),
			Free_Size NUMERIC(38,3))		

		SELECT @iCount = COUNT(name) from master.dbo.sysdatabases where DATABASEPROPERTYEX(name,'status') = 'ONLINE'
		SELECT @TotalSizeDB = SUM(size) from #Complete_Info
		
		SELECT @RegValue = NULL
		EXEC master.dbo.xp_regread 'HKEY_LOCAL_MACHINE','SOFTWARE\Microsoft\Windows NT\CurrentVersion\', 
				N'ProductName',@RegValue OUTPUT 	
		SELECT @OS_Name = @RegValue

		
		INSERT INTO @MSVER([index],name,internal_value,character_value) EXEC master.dbo.xp_msver PhysicalMemory
		
		SELECT @RAMSize = internal_value FROM @MSVER WHERE name LIKE 'PhysicalMemory'
		
		SELECT @CPU_Count = cpu_count FROM [sys].[dm_os_sys_info]
	
	
		SELECT @SQLCMD = 'USE [?] INSERT INTO #Complete_Info([DBname],[LName],[PName],[size],[usedspace],[Max_File_Size],[File_Growth],File_Type,Groupname) 
					 SELECT DB_Name(),name,filename,size*8,CAST(fileproperty(name,''spaceused'''+') as INT)*8,maxsize,growth,
								CASE WHEN (status & 0x40) <> 0 THEN ''Log File''
							WHEN (status & 0x2) <> 0 THEN ''Data File''
							ELSE CAST(status AS VARCHAR(2000)) END,[File Group] from sysfiles
								LEFT JOIN (SELECT data_space_id,[File Group] = CASE WHEN is_default = 1 THEN name+'' (Default)''
								ELSE name END FROM sys.filegroups) FileGroup
								ON sysfiles.groupid = FileGroup.data_space_id'
					
		EXEC master.dbo.sp_MSforeachdb @SQLCMD

		DELETE FROM #Complete_Info WHERE DB_NAME(DB_ID1) NOT LIKE @Search_Database_Name  
		
		UPDATE #Complete_Info SET DB_ID1 = DB_ID(DBname)
		
		UPDATE #Complete_Info SET freespace = size - usedspace 

		UPDATE #Complete_Info SET DB_Owner = SUSER_SNAME(sid),
								Recovery_Model = cast(DATABASEPROPERTYEX(name,'recovery') as varchar(10)) 
					FROM master.sys.sysdatabases where DB_ID1 =dbid

		SELECT @Total_Size = SUM(size)
			FROM #Complete_Info


		INSERT INTO @Drive_DB_Info(Drive_Letter,Drive_Label,Drive_Total_Size_MB,Drive_Used_Size_MB,Drive_Free_Size_MB)
		SELECT
			DISTINCT LEFT(vs.volume_mount_point,1) AS [Drive]
			,vs.logical_volume_name
			,CONVERT(DECIMAL(18,3),vs.total_bytes/1048576.0) AS [Total Size (MB)]
			,CONVERT(DECIMAL(18,3),vs.total_bytes/1048576.0) - CONVERT(DECIMAL(18,3),vs.available_bytes/1048576.0) AS [Used Size (MB)]
			,CONVERT(DECIMAL(18,3),vs.available_bytes/1048576.0) AS [Available Size (MB)]
			FROM sys.master_files AS mf WITH (NOLOCK)
			CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.[file_id]) AS vs 
			WHERE DB_NAME(mf.database_id) LIKE @Search_Database_Name 
			ORDER BY 1
			OPTION (RECOMPILE)

		UPDATE @Drive_DB_Info SET No_of_Files = 
			(SELECT [Files_Count]FROM
			(SELECT [Drive] = LEFT(PName,1) 
				,[Files_Count] = COUNT(*)
				FROM #Complete_Info
				WHERE DB_NAME(DB_ID1) LIKE @Search_Database_Name 
				GROUP BY LEFT(PName,1)) A
				WHERE [Drive] = Drive_Letter)

		
		UPDATE @Drive_DB_Info SET DB_Total_Size = 
			(SELECT [Total_Size] FROM
			(SELECT [Drive] = LEFT(PName,1) 
				,[Total_Size] = SUM(size)			
				FROM #Complete_Info
				WHERE DB_NAME(DB_ID1) LIKE @Search_Database_Name 
				GROUP BY LEFT(PName,1)) A
				WHERE [Drive] = Drive_Letter)

		UPDATE @Drive_DB_Info SET DB_Used_Size = 
			(SELECT [Used_Size] FROM
			(SELECT [Drive] = LEFT(PName,1) 
				,[Used_Size] = SUM(usedspace)			
				FROM #Complete_Info
				WHERE DB_NAME(DB_ID1) LIKE @Search_Database_Name 
				GROUP BY LEFT(PName,1)) A
				WHERE [Drive] = Drive_Letter)

		UPDATE @Drive_DB_Info SET DB_Free_Size = 
				DB_Total_Size - DB_Used_Size

		UPDATE @Drive_DB_Info SET Non_DB_Size =
				Drive_Used_Size_MB - (DB_Total_Size/1024.0)

		INSERT INTO @Total_Size_Summary(Weightage,Database_ID,Database_Name,DB_Files_Count,Used_Size,Free_Size,Total_Size)	
		SELECT	[Weight] = CAST((SUM(size)/@Total_Size)*100 AS NUMERIC(38,3))
				,DB_ID1
				,[Database Name] = DB_NAME(DB_ID1)
				,[DB Files Count] = count(*)
				,SUM(usedspace)
				,SUM(freespace)
				,SUM(size)
			FROM #Complete_Info
			WHERE DB_NAME(DB_ID1) LIKE @Search_Database_Name 
			GROUP BY DB_ID1
			ORDER BY 1 DESC
		

		UPDATE @Total_Size_Summary SET Data_Size = 
				(SELECT SUM(size) FROM #Complete_Info
					WHERE DB_ID1 = Database_ID AND File_Type = 'Data File')

		UPDATE @Total_Size_Summary SET Log_Size = 
				(SELECT SUM(size) FROM #Complete_Info
					WHERE  DB_ID1 = Database_ID AND File_Type = 'Log File' )

		SELECT	[Server Name] = SERVERPROPERTY('servername')
				,[OS Name] = @OS_Name
				,[RAM Size] = CASE WHEN ABS(@RAMSize)< 1024 then CAST((@RAMSize) AS VARCHAR(10)) +' MB' 
								     ELSE CAST(CAST((@RAMSize)/1024  AS NUMERIC(10,3)) as varchar(50)) +' GB' END	
				,[CPU Count] = @CPU_Count
				,[SQL Version] = CASE LEFT(CONVERT(VARCHAR, SERVERPROPERTY('ProductVersion')),4) 
										WHEN '8.00' THEN 'SQL Server 2000'
										WHEN '9.00' THEN 'SQL Server 2005'
										WHEN '10.0' THEN 'SQL Server 2008'
										WHEN '10.5' THEN 'SQL Server 2008 R2'
										WHEN '11.0' THEN 'SQL Server 2012'
										WHEN '12.0' THEN 'SQL Server 2014'
										WHEN '13.0' THEN 'SQL Server 2016'
										WHEN '14.0' THEN 'SQL Server 2017'
										ELSE 'SQL Server 2017+' END
				,[SQL Build (SP)] = CAST(SERVERPROPERTY('ProductVersion')  as VARCHAR(30)) + ' ( '+ CAST(SERVERPROPERTY('ProductLevel')  as VARCHAR(30)) +' )' 						
				,[SQL Edition] = CAST(SERVERPROPERTY('Edition')  as VARCHAR(30)) 
				,[SQL Collation] = CAST(SERVERPROPERTY('Collation')  as VARCHAR(30))
				

		SELECT	[Online Databases] = @iCount
				,'(' = '('
				,[Total Used Size] = 			
						CASE WHEN SUM(Used_Size)< 1024 then CAST((SUM(Used_Size)) AS VARCHAR(10)) +' KB' 
					    WHEN SUM(Used_Size)< 1048576 then CAST(CAST((SUM(Used_Size))/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN SUM(Used_Size)< 1073741824  then CAST(CAST((SUM(Used_Size))/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((SUM(Used_Size))/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '+
						+CAST(CAST((SUM(Used_Size)/SUM(Total_Size))*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
				,[+] = '+'
				,[Total Free Size] = 			
						CASE WHEN SUM(Free_Size)< 1024 then CAST((SUM(Free_Size)) AS VARCHAR(10)) +' KB' 
					    WHEN SUM(Free_Size)< 1048576 then CAST(CAST((SUM(Free_Size))/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN SUM(Free_Size)< 1073741824  then CAST(CAST((SUM(Free_Size))/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((SUM(Free_Size))/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '+
						+CAST(CAST((SUM(Free_Size)/SUM(Total_Size))*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
				,')' = ')'
				,[=] = '='
				,[Total Size] = 			
						CASE WHEN SUM(Total_Size)< 1024 then CAST((SUM(Total_Size)) AS VARCHAR(10)) +' KB' 
					    WHEN SUM(Total_Size)< 1048576 then CAST(CAST((SUM(Total_Size))/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN SUM(Total_Size)< 1073741824  then CAST(CAST((SUM(Total_Size))/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((SUM(Total_Size))/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END 
				,[=] = '='
				,'(' = '('
				,[Data Size] = 
						CASE WHEN SUM(Data_Size)< 1024 then CAST(SUM(Data_Size) AS VARCHAR(10)) +' KB' 
					    WHEN SUM(Data_Size)< 1048576 then CAST(CAST((SUM(Data_Size))/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN SUM(Data_Size)< 1073741824  then CAST(CAST((SUM(Data_Size))/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((SUM(Data_Size))/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '+
						+CAST(CAST((SUM(Data_Size)/SUM(Total_Size))*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
				,[+] = '+'
				,[Log Size] = 
						CASE WHEN SUM(Log_Size)< 1024 then CAST(SUM(Log_Size) AS VARCHAR(10)) +' KB' 
					    WHEN SUM(Log_Size)< 1048576 then CAST(CAST((SUM(Log_Size))/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN SUM(Log_Size)< 1073741824  then CAST(CAST((SUM(Log_Size))/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((SUM(Log_Size))/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '+
						+CAST(CAST((SUM(Log_Size)/SUM(Total_Size))*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,')' = ')'
			FROM @Total_Size_Summary
			WHERE Database_Name LIKE @Search_Database_Name 

		SELECT 
			Drive_Letter
			,Drive_Label
			,No_of_Files
			,'{' = '{'
			,[Drive Used] = 
				CASE WHEN Drive_Used_Size_MB< 1024 then CAST(CAST(((Drive_Used_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Drive_Used_Size_MB)< 1048576 then CAST(CAST(((Drive_Used_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						WHEN (Drive_Used_Size_MB)< 1073741824  then CAST(CAST(((Drive_Used_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
						ELSE CAST(CAST(((Drive_Used_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END + ' ( '
						+CAST(CAST((Drive_Used_Size_MB/Drive_Total_Size_MB)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'+' = '+'
			,[Drive Free] = 
				CASE WHEN Drive_Free_Size_MB< 1024 then CAST(CAST(((Drive_Free_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Drive_Free_Size_MB)< 1048576 then CAST(CAST(((Drive_Free_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						WHEN (Drive_Free_Size_MB)< 1073741824  then CAST(CAST(((Drive_Free_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
						ELSE CAST(CAST(((Drive_Free_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END+ ' ( '
						+CAST(CAST((Drive_Free_Size_MB/Drive_Total_Size_MB)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'}' = '}'
			,'=' = '='
			,[Drive Total] =
				CASE WHEN Drive_Total_Size_MB< 1024 then CAST(CAST(((Drive_Total_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Drive_Total_Size_MB)< 1048576 then CAST(CAST(((Drive_Total_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						WHEN (Drive_Total_Size_MB)< 1073741824  then CAST(CAST(((Drive_Total_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
						ELSE CAST(CAST(((Drive_Total_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END
			,'=' = '='
			,'{' = '{'
			,[DB Total] = 
				CASE WHEN DB_Total_Size< 1024 then CAST(CAST(((DB_Total_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (DB_Total_Size)< 1048576 then CAST(CAST(((DB_Total_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (DB_Total_Size)< 1073741824  then CAST(CAST(((DB_Total_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((DB_Total_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST(((DB_Total_Size/1024.0)/Drive_Used_Size_MB)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'[' = '['							
			,[DB Used] = 
				CASE WHEN DB_Used_Size< 1024 then CAST(CAST(((DB_Used_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (DB_Used_Size)< 1048576 then CAST(CAST(((DB_Used_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (DB_Used_Size)< 1073741824  then CAST(CAST(((DB_Used_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((DB_Used_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((DB_Used_Size/DB_Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'+' = '+'
			,[DB Free] =
				CASE WHEN DB_Free_Size< 1024 then CAST(CAST(((DB_Free_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (DB_Free_Size)< 1048576 then CAST(CAST(((DB_Free_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (DB_Free_Size)< 1073741824  then CAST(CAST(((DB_Free_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((DB_Free_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END+ ' ( '
						+CAST(CAST((DB_Free_Size/DB_Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,']' = ']'
			,'}' = '}'
			,'+' = '+'
			,'{' = '{'
			,Non_DB_Size =
				CASE WHEN Non_DB_Size< 1024 then CAST(CAST(((Non_DB_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Non_DB_Size)< 1048576 then CAST(CAST(((Non_DB_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						WHEN (Non_DB_Size)< 1073741824  then CAST(CAST(((Non_DB_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
						ELSE CAST(CAST(((Non_DB_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END + ' ( '
						+CAST(CAST((Non_DB_Size/Drive_Used_Size_MB)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'	
			,'}' = '}'
		 FROM @Drive_DB_Info ORDER BY 1
		

		SELECT Weightage
			,DBID = Database_ID
			,Database_Name
			,Files = DB_Files_Count
			,'(' = '('
			,Used_Size = CASE WHEN Used_Size< 1024 then CAST(CAST(((Used_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Used_Size)< 1048576 then CAST(CAST(((Used_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Used_Size)< 1073741824  then CAST(CAST(((Used_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Used_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((Used_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'+' = '+'
			,Free_Size = CASE WHEN Free_Size< 1024 then CAST(CAST(((Free_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Free_Size)< 1048576 then CAST(CAST(((Free_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Free_Size)< 1073741824  then CAST(CAST(((Free_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Free_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END+ ' ( '
						+CAST(CAST((Free_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,')' = ')'
			,'=' = '='
			,Total_Size = CASE WHEN Total_Size< 1024 then CAST(CAST(((Total_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Total_Size)< 1048576 then CAST(CAST(((Total_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Total_Size)< 1073741824  then CAST(CAST(((Total_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Total_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END
			,'=' = '='
			,'(' = '('
			,Data_Size = CASE WHEN Data_Size< 1024 then CAST(CAST(((Data_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Data_Size)< 1048576 then CAST(CAST(((Data_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Data_Size)< 1073741824  then CAST(CAST(((Data_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Data_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END+ ' ( '
						+CAST(CAST((Data_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'+' = '+'
			,Log_Size = CASE WHEN Log_Size< 1024 then CAST(CAST(((Log_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Log_Size)< 1048576 then CAST(CAST(((Log_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Log_Size)< 1073741824  then CAST(CAST(((Log_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Log_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END+ ' ( '
						+CAST(CAST((Log_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,')' = ')'
			FROM @Total_Size_Summary 
			ORDER BY 1 DESC



		INSERT INTO @File_Group_Analysis(Database_Name,File_Group,No_of_Files,Total_Size,Used_Size,Free_Size)
		SELECT DBname
				,[Groupname] = ISNULL(Groupname,'Transaction Log')
				,[No_of_Files] = COUNT(*)
				,[Total_Size] = SUM(size)
				,[Used_Size] = SUM(usedspace)
				,[Free_Size] = SUM(freespace)
				FROM #Complete_Info
				WHERE DBname LIKE @Search_Database_Name 
			GROUP BY DBname,Groupname
			ORDER BY DBname,Groupname
			
		SELECT 
			Database_Name
			,File_Group
			,No_of_Files
			,Total_Size = CASE WHEN Total_Size< 1024 then CAST(CAST(((Total_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
					WHEN (Total_Size)< 1048576 then CAST(CAST(((Total_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
					WHEN (Total_Size)< 1073741824  then CAST(CAST(((Total_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					ELSE CAST(CAST(((Total_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END
			,'(' = '('
			,Used_Size = CASE WHEN Used_Size< 1024 then CAST(CAST(((Used_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Used_Size)< 1048576 then CAST(CAST(((Used_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Used_Size)< 1073741824  then CAST(CAST(((Used_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Used_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((Used_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,'+' = '+'
			,Free_Size = CASE WHEN Free_Size< 1024 then CAST(CAST(((Free_Size)) AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
						WHEN (Free_Size)< 1048576 then CAST(CAST(((Free_Size))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
						WHEN (Free_Size)< 1073741824  then CAST(CAST(((Free_Size))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
						ELSE CAST(CAST(((Free_Size))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END+ ' ( '
						+CAST(CAST((Free_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
			,')' = ')'

		 FROM @File_Group_Analysis
		 ORDER BY Database_Name,File_Group

		INSERT INTO @Files_Wise_Analysis(Database_Name,File_Location,File_Type,No_of_Files,Total_Size,Used_Size,Free_Size)		
		SELECT [Database Name],[Files Residing Folders],
				[File_Type] = CASE	WHEN [File_Extension] LIKE 'mdf' THEN 'Master Data File'
									WHEN [File_Extension] LIKE 'ndf' THEN 'Secondary Data File'
									WHEN [File_Extension] LIKE 'ldf' THEN 'Log File'
									ELSE [File_Extension]
				END
				,[Number of Files]= COUNT([File_Extension]) 
				,SUM([Size])
				,SUM([Used_Size])
				,SUM([Free_Size])
				FROM
		(select [Database Name] = DB_NAME(DB_ID1),
				[Files Residing Folders] = SUBSTRING(PName,1,LEN(PName)-CHARINDEX('\',REVERSE(PName),1)),
				[File_Extension] = right(PName,3),
				[Size] = SUM(size),
				[Used_Size] = SUM(usedspace),
				[Free_Size] = SUM(freespace)
		 FROM #Complete_Info
		 WHERE DB_NAME(DB_ID1) LIKE @Search_Database_Name
		 GROUP BY DB_ID1,PName) FILES
		 GROUP BY [Database Name],[Files Residing Folders],[File_Extension]
		 ORDER BY [Database Name],[Files Residing Folders],[File_Extension] DESC

		SELECT	Database_Name
				,File_Location
				,File_Type,No_of_Files
				,Total_Size = CASE WHEN Total_Size< 1024 then CAST(CAST(Total_Size AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
					WHEN Total_Size< 1048576 then CAST(CAST(Total_Size/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
					WHEN Total_Size< 1073741824  then CAST(CAST(Total_Size/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					ELSE CAST(CAST(Total_Size/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END
				,'=' = '='
				,'(' = '('
				,Used_Size = CASE WHEN Used_Size< 1024 then CAST(CAST(Used_Size AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
					WHEN Used_Size< 1048576 then CAST(CAST(Used_Size/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
					WHEN Used_Size< 1073741824  then CAST(CAST(Used_Size/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					ELSE CAST(CAST(Used_Size/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((Used_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
				,'+' = '+'
				,Free_Size = CASE WHEN Free_Size< 1024 then CAST(CAST(Free_Size AS NUMERIC(10,3))AS VARCHAR(20)) +' KB' 
					WHEN Free_Size< 1048576 then CAST(CAST(Free_Size/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
					WHEN Free_Size< 1073741824  then CAST(CAST(Free_Size/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					ELSE CAST(CAST(Free_Size/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((Free_Size/Total_Size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )'
				,')' = ')'
				FROM @Files_Wise_Analysis






		SELECT	 			
 				DBname  AS [Database Name],
 				RTRIM(Recovery_Model) AS [Recovery Model],
 				DB_Owner AS [Database Owner],
				RTRIM(LName) AS [Logical Filename],
				[Physical File Location] = SUBSTRING(PName, 1, LEN(PName) - CHARINDEX('\', REVERSE(PName), 1)),
				[Physical File Name] = SUBSTRING(PName, LEN(PName) - (CHARINDEX('\', REVERSE(PName), 1) - 2), LEN(PName)),
				[File Type] = File_Type,						
				[File Size] = 			
						CASE WHEN size< 1024 then CAST((size) AS VARCHAR(10)) +' KB' 
					    WHEN size< 1048576 then CAST(CAST((size)/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN size< 1073741824  then CAST(CAST((size)/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((size)/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END,				
				[Used Space] = 
						CASE WHEN usedspace< 1024 then CAST((usedspace) AS VARCHAR(10)) +' KB' 
					    WHEN usedspace< 1048576 then CAST(CAST((usedspace)/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN usedspace< 1073741824  then CAST(CAST((usedspace)/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((usedspace)/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((usedspace/size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )',
				[Free Space] = 
						CASE WHEN freespace< 1024 then CAST((freespace) AS VARCHAR(10)) +' KB' 
					    WHEN freespace< 1048576 then CAST(CAST((freespace)/1024 AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
	 				    WHEN freespace< 1073741824  then CAST(CAST((freespace)/1048576 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
					    ELSE CAST(CAST((freespace)/1073741824 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' END + ' ( '
						+CAST(CAST((freespace/size)*100 AS NUMERIC(30,3)) AS VARCHAR(100)) + ' % )',
				[File Growth] = 
						CASE	WHEN File_Growth = 0 THEN 'DISABLED'
							WHEN [File_Growth] LIKE '__' THEN CAST([File_Growth] AS VARCHAR(5))+' %'
							ELSE 
								CASE WHEN (File_Growth*8)< 1024 then CAST(((File_Growth*8)) AS VARCHAR(10)) +' KB' 
								WHEN (File_Growth*8)< 1048576 then CAST(((File_Growth*8))/1024 AS VARCHAR(20)) +' MB' 
	 							WHEN (File_Growth*8)< 1073741824  then CAST(((File_Growth*8))/1048576 AS VARCHAR(20)) +' GB' 
								ELSE CAST(((File_Growth*8))/1073741824 AS VARCHAR(20)) +' TB' END						
						END,							
				[Max File Size] =
							CASE WHEN File_Growth =0  THEN 'No Growth  '
							     WHEN  Max_File_Size = -1 THEN 'Max Growth'									 
							ELSE  
								CASE WHEN (Max_File_Size*8)< 1024 then CAST(((Max_File_Size*8)) AS VARCHAR(10)) +' KB' 
								WHEN (Max_File_Size*8)< 1048576 then CAST(((Max_File_Size*8))/1024 AS VARCHAR(20)) +' MB' 
	 							WHEN (Max_File_Size*8)< 1073741824  then CAST(((Max_File_Size*8))/1048576 AS VARCHAR(20)) +' GB' 
								ELSE CAST(((Max_File_Size*8))/1073741824 AS VARCHAR(20)) +' TB' END
						END 
				,			
				Groupname AS [File Group] 
				FROM #Complete_Info 
				WHERE DBname LIKE @Search_Database_Name
				order by 1

DROP TABLE #Complete_Info
SET NOCOUNT OFF
END