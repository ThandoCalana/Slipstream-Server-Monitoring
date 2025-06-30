USE [server_monitoring]
GO

/****** Object:  Table [dbo].[ram_metrics]    Script Date: 19-Jun-25 2:46:35 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ram_metrics](
	[Timestamp] [datetime] NULL,
	[ProcessName] [nvarchar](255) NULL,
	[RAM_Used_MB] [float] NULL,
	[RAM_Used_Percent] [float] NULL
) ON [PRIMARY]
GO


