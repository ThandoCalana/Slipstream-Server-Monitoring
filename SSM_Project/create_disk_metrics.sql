USE [server_monitoring]
GO

/****** Object:  Table [dbo].[disk_metrics]    Script Date: 19-Jun-25 2:46:30 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[disk_metrics](
	[Timestamp] [datetime] NULL,
	[UsedSpace_GB] [float] NULL,
	[FreeSpace_GB] [float] NULL,
	[TotalSpace_GB] [float] NULL
) ON [PRIMARY]
GO


