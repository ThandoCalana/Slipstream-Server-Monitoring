USE [server_monitoring]
GO

/****** Object:  Table [dbo].[cpu_metrics]    Script Date: 19-Jun-25 2:46:18 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[cpu_metrics](
	[Timestamp] [datetime] NULL,
	[ProcessName] [nvarchar](255) NULL,
	[CPU_Usage_Percent] [float] NULL
) ON [PRIMARY]
GO


