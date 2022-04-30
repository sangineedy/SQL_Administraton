# SQL_Administraton

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
