MODULE ELMFIRE_INIT

USE ELMFIRE_VARS

IMPLICIT NONE

CONTAINS

! *****************************************************************************
SUBROUTINE SET_MISC_PARAMETERS(R1)
! *****************************************************************************

REAL, DIMENSION(:) :: R1
INTEGER :: I
I = NUM_PARAMETERS_RASTERS + NUM_PARAMETERS_SPOTTING

IF (PERTURB_WIND_DIRECTION_FLUCTUATION_INTENSITY) THEN
   I = I + 1
   WIND_DIRECTION_FLUCTUATION_INTENSITY = WIND_DIRECTION_FLUCTUATION_INTENSITY_MIN + &
   R1(I)*(WIND_DIRECTION_FLUCTUATION_INTENSITY_MAX - WIND_DIRECTION_FLUCTUATION_INTENSITY_MIN)
   COEFFS_UNSCALED(I)=WIND_DIRECTION_FLUCTUATION_INTENSITY
ENDIF

IF (PERTURB_WIND_SPEED_FLUCTUATION_INTENSITY) THEN
   I = I + 1
   WIND_SPEED_FLUCTUATION_INTENSITY = WIND_SPEED_FLUCTUATION_INTENSITY_MIN + &
   R1(I)*(WIND_SPEED_FLUCTUATION_INTENSITY_MAX - WIND_SPEED_FLUCTUATION_INTENSITY_MIN)
   COEFFS_UNSCALED(I)=WIND_SPEED_FLUCTUATION_INTENSITY
ENDIF

! *****************************************************************************
END SUBROUTINE SET_MISC_PARAMETERS
! *****************************************************************************

! *****************************************************************************
SUBROUTINE CHECK_INPUTS(GOOD_INPUTS)
! *****************************************************************************

LOGICAL, INTENT(OUT) :: GOOD_INPUTS

GOOD_INPUTS = .TRUE. 

IF (MODE .NE. 2 .AND. DT_METEOROLOGY .LE. 0.) THEN
   WRITE(*,*) 'Specify DT_METEOROLOGY in the &INPUTS namelist group.'
   GOOD_INPUTS = .FALSE. 
ENDIF

! *****************************************************************************
END SUBROUTINE CHECK_INPUTS
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INIT_LOOKUP_TABLES
! *****************************************************************************

INTEGER :: I, ICC, ICH
REAL :: CC1, CH1

! Initialize trigonometric arrays (tan^2(slp), sin(asp-180.), cos(asp-180.)
DO I =0,89
   TANSLP2(I) = TAN(REAL(I)*PIO180)
   COSSLP (I) = COS(REAL(I)*PIO180)
ENDDO
TANSLP2(90) = 100.0
TANSLP2(:)=TANSLP2(:)*TANSLP2(:)

DO I=0,360
   ABSSINASP(I)=ABS(SIN(REAL(I)*PIO180))
   ABSCOSASP(I)=ABS(COS(REAL(I)*PIO180))
   SINASPM180(I)=SIN((REAL(I) - 180.)*PIO180)
   COSASPM180(I)=COS((REAL(I) - 180.)*PIO180)
ENDDO

! Sine and Cosine of wind direction minus pi, used in UX_AND_UY routines
DO I = 0, 3600
   SINWDMPI(I) = SIN( (REAL(I)*0.1 - 180.) * PIO180)
   COSWDMPI(I) = COS( (REAL(I)*0.1 - 180.) * PIO180)
ENDDO

! Set up sheltered wind adjustment factor table
DO ICC = 0, 100
   CC1=REAL(ICC)*0.01
   DO ICH = 0, 120
      CH1 = REAL(ICH)
      SHELTERED_WAF_TABLE(ICC,ICH) = CALC_WIND_ADJUSTMENT_FACTOR_SINGLE(CC1, CH1, 0.)
   ENDDO
ENDDO

! *****************************************************************************
END SUBROUTINE INIT_LOOKUP_TABLES
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INIT_RASTERS
! *****************************************************************************

INTEGER :: IX, IY, J
REAL :: ARG

CALL CALC_WIND_ADJUSTMENT_FACTOR_EVERYWHERE(CC, CH, FBFM, WAF)

! 1 - cos (slp)
DO IY = 1, FBFM%NROWS
DO IX = 1, FBFM%NCOLS
   IF (SLP%R4(IX,IY,1) .NE. SLP%NODATA_VALUE) THEN 
      ARG = MIN(MAX(SLP%R4(IX,IY,1),0.),90.)
      OMCOSSLPRAD%R4(IX,IY,1) = 1. - COSSLP(NINT(ARG))
   ELSE
      OMCOSSLPRAD%R4(IX,IY,1) = 0.
   ENDIF
ENDDO
ENDDO

! Nonburnable mask
DO IY = 1, FBFM%NROWS
DO IX = 1, FBFM%NCOLS
   J = FBFM%I2(IX,IY,1)
   IF ( (J .GE. 90 .AND. J .LE. 100) .OR. J .EQ. 256 .OR. J .LE. 0) THEN
      ISNONBURNABLE(IX,IY) = .TRUE.
   ELSE
      ISNONBURNABLE(IX,IY) = .FALSE.
   ENDIF
   IF (USE_HAMADA .AND. J .EQ. 91) ISNONBURNABLE(IX,IY) = .FALSE.
ENDDO
ENDDO

IF (USE_IGNITION_MASK .AND. ADD_TO_IGNITION_MASK .GT. 0.) THEN
   DO IY = 1, IGN_MASK%NROWS
   DO IX = 1, IGN_MASK%NCOLS
      IF (.NOT. ISNONBURNABLE(IX,IY) ) IGN_MASK%R4(IX,IY,1) = IGN_MASK%R4(IX,IY,1) + ADD_TO_IGNITION_MASK
   ENDDO
   ENDDO
ENDIF

! *****************************************************************************
END SUBROUTINE INIT_RASTERS
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SETUP_SHARED_MEMORY_1
! *****************************************************************************

INTEGER :: IERR

ANALYSIS_NCOLS = ASP%NCOLS
ANALYSIS_NROWS = ASP%NROWS
WX_NCOLS       = WS%NCOLS
WX_NROWS       = WS%NROWS
WX_NBANDS      = WS%NBANDS

ARRAYSHAPE_ANALYSIS_SINGLEBAND=(/ ANALYSIS_NCOLS, ANALYSIS_NROWS, 1 /)
ARRAYSHAPE_CALIBRATION=(/ ANALYSIS_NCOLS, ANALYSIS_NROWS, NUM_CALIBRATION_TIMES /)
ARRAYSHAPE_WX=(/ WX_NCOLS, WX_NROWS, WX_NBANDS /)
ARRAYSHAPE_ISNONBURNABLE=(/ ANALYSIS_NCOLS, ANALYSIS_NROWS /)

IF (IRANK_HOST .EQ. 0) THEN
   ANALYSIS_SINGLEBAND_SIZE_REAL = INT (ANALYSIS_NCOLS*ANALYSIS_NROWS,MPI_ADDRESS_KIND                      ) * 4_MPI_ADDRESS_KIND
   ANALYSIS_SINGLEBAND_SIZE_INT  = INT (ANALYSIS_NCOLS*ANALYSIS_NROWS,MPI_ADDRESS_KIND                      ) * 2_MPI_ADDRESS_KIND
   ANALYSIS_SINGLEBAND_SIZE_L1   = INT (ANALYSIS_NCOLS*ANALYSIS_NROWS,MPI_ADDRESS_KIND                      ) * 1_MPI_ADDRESS_KIND
   CALIBRATION_SIZE              = INT (ANALYSIS_NCOLS*ANALYSIS_NROWS*NUM_CALIBRATION_TIMES,MPI_ADDRESS_KIND) * 2_MPI_ADDRESS_KIND
   WX_SIZE                       = INT (WX_NCOLS*WX_NROWS*WX_NBANDS,MPI_ADDRESS_KIND                        ) * 4_MPI_ADDRESS_KIND
ELSE
   ANALYSIS_SINGLEBAND_SIZE_REAL = 0_MPI_ADDRESS_KIND
   ANALYSIS_SINGLEBAND_SIZE_INT  = 0_MPI_ADDRESS_KIND
   ANALYSIS_SINGLEBAND_SIZE_L1   = 0_MPI_ADDRESS_KIND
   CALIBRATION_SIZE              = 0_MPI_ADDRESS_KIND
   WX_SIZE                       = 0_MPI_ADDRESS_KIND
ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, WS_PTR   , WIN_WS   )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, WD_PTR   , WIN_WD   )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, M1_PTR   , WIN_M1   )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, M10_PTR  , WIN_M10  )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, M100_PTR , WIN_M100 )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, MLH_PTR  , WIN_MLH  )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, MLW_PTR  , WIN_MLW  )
CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, MFOL_PTR , WIN_MFOL )

IF (USE_ERC) THEN
   CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, ERC_PTR    , WIN_ERC    )
   CALL MPI_WIN_ALLOCATE_SHARED (WX_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, IGNFAC_PTR , WIN_IGNFAC )
ENDIF

IF (USE_IGNITION_MASK) CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, IGN_MASK_PTR      , WIN_IGN_MASK     )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, ASP_PTR           , WIN_ASP          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, CBH_PTR           , WIN_CBH          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, CBD_PTR           , WIN_CBD          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, CC_PTR            , WIN_CC           )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, CH_PTR            , WIN_CH           )
IF (MODE .NE. 2) CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, DEM_PTR           , WIN_DEM          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_INT , DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, FBFM_PTR          , WIN_FBFM         )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, SLP_PTR           , WIN_SLP          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, ADJ_PTR           , WIN_ADJ          )
IF (MODE .NE. 2) CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, PHI0_PTR          , WIN_PHI0         )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, WAF_PTR           , WIN_WAF          )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, OMCOSSLPRAD_PTR   , WIN_OMCOSSLPRAD  )
CALL MPI_WIN_ALLOCATE_SHARED (ANALYSIS_SINGLEBAND_SIZE_L1  , DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, ISNONBURNABLE_PTR , WIN_ISNONBURNABLE )

IF (USE_POPULATION_DENSITY) CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, POPULATION_DENSITY_PTR , WIN_POPULATION_DENSITY)
IF (USE_REAL_ESTATE_VALUE ) CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, REAL_ESTATE_VALUE_PTR  , WIN_REAL_ESTATE_VALUE )
IF (USE_LAND_VALUE        ) CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, LAND_VALUE_PTR         , WIN_LAND_VALUE        )
IF (USE_SDI               ) CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, SDI_PTR                , WIN_SDI)
IF (USE_HAMADA) THEN
   CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, HAMADA_A_PTR  , WIN_HAMADA_A )
   CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, HAMADA_D_PTR  , WIN_HAMADA_D )
   CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, HAMADA_FB_PTR , WIN_HAMADA_FB)
ENDIF
IF (USE_PYROMES) CALL MPI_WIN_ALLOCATE_SHARED(ANALYSIS_SINGLEBAND_SIZE_INT, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, PYROMES_PTR, WIN_PYROMES)

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

IF (IRANK_HOST .NE. 0) THEN

   CALL MPI_WIN_SHARED_QUERY(WIN_WS  , 0, WX_SIZE, DISP_UNIT, WS_PTR   )
   CALL MPI_WIN_SHARED_QUERY(WIN_WD  , 0, WX_SIZE, DISP_UNIT, WD_PTR   )
   CALL MPI_WIN_SHARED_QUERY(WIN_M1  , 0, WX_SIZE, DISP_UNIT, M1_PTR   )
   CALL MPI_WIN_SHARED_QUERY(WIN_M10 , 0, WX_SIZE, DISP_UNIT, M10_PTR  )
   CALL MPI_WIN_SHARED_QUERY(WIN_M100, 0, WX_SIZE, DISP_UNIT, M100_PTR )
   CALL MPI_WIN_SHARED_QUERY(WIN_MLH , 0, WX_SIZE, DISP_UNIT, MLH_PTR  )
   CALL MPI_WIN_SHARED_QUERY(WIN_MLW , 0, WX_SIZE, DISP_UNIT, MLW_PTR  )
   CALL MPI_WIN_SHARED_QUERY(WIN_MFOL, 0, WX_SIZE, DISP_UNIT, MFOL_PTR )

   IF (USE_ERC) THEN
      CALL MPI_WIN_SHARED_QUERY(WIN_ERC    , 0, WX_SIZE, DISP_UNIT, ERC_PTR    )
      CALL MPI_WIN_SHARED_QUERY(WIN_IGNFAC , 0, WX_SIZE, DISP_UNIT, IGNFAC_PTR )
   ENDIF

   IF (USE_IGNITION_MASK)    CALL MPI_WIN_SHARED_QUERY(WIN_IGN_MASK          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, IGN_MASK_PTR)
   CALL MPI_WIN_SHARED_QUERY(WIN_ASP          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, ASP_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_CBH          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, CBH_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_CBD          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, CBD_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_CC           , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, CC_PTR            )
   CALL MPI_WIN_SHARED_QUERY(WIN_CH           , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, CH_PTR            )
   IF (MODE .NE. 2) CALL MPI_WIN_SHARED_QUERY(WIN_DEM          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, DEM_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_FBFM         , 0, ANALYSIS_SINGLEBAND_SIZE_INT , DISP_UNIT, FBFM_PTR          )
   CALL MPI_WIN_SHARED_QUERY(WIN_SLP          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, SLP_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_ADJ          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, ADJ_PTR           )
   IF (MODE .NE. 2) CALL MPI_WIN_SHARED_QUERY(WIN_PHI0         , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, PHI0_PTR          )
   CALL MPI_WIN_SHARED_QUERY(WIN_WAF          , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, WAF_PTR           )
   CALL MPI_WIN_SHARED_QUERY(WIN_OMCOSSLPRAD  , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, OMCOSSLPRAD_PTR   )

   CALL MPI_WIN_SHARED_QUERY(WIN_ISNONBURNABLE, 0, ANALYSIS_SINGLEBAND_SIZE_L1   , DISP_UNIT, ISNONBURNABLE_PTR )

   IF (USE_POPULATION_DENSITY) CALL MPI_WIN_SHARED_QUERY(WIN_POPULATION_DENSITY,   0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, POPULATION_DENSITY_PTR )
   IF (USE_REAL_ESTATE_VALUE ) CALL MPI_WIN_SHARED_QUERY(WIN_REAL_ESTATE_VALUE ,   0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, REAL_ESTATE_VALUE_PTR  )
   IF (USE_LAND_VALUE        ) CALL MPI_WIN_SHARED_QUERY(WIN_LAND_VALUE        ,   0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, LAND_VALUE_PTR         )
   IF (USE_SDI               ) CALL MPI_WIN_SHARED_QUERY(WIN_SDI               ,   0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, SDI_PTR                )
   IF (USE_HAMADA) THEN
      CALL MPI_WIN_SHARED_QUERY(WIN_HAMADA_A , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, HAMADA_A_PTR  )
      CALL MPI_WIN_SHARED_QUERY(WIN_HAMADA_D , 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, HAMADA_D_PTR  )
      CALL MPI_WIN_SHARED_QUERY(WIN_HAMADA_FB, 0, ANALYSIS_SINGLEBAND_SIZE_REAL, DISP_UNIT, HAMADA_FB_PTR )
   ENDIF
   IF (USE_PYROMES) CALL MPI_WIN_SHARED_QUERY(WIN_PYROMES, 0, ANALYSIS_SINGLEBAND_SIZE_INT, DISP_UNIT, PYROMES_PTR)

ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

CALL C_F_POINTER(WS_PTR   , WS%R4  , ARRAYSHAPE_WX)
CALL C_F_POINTER(WD_PTR   , WD%R4  , ARRAYSHAPE_WX)
CALL C_F_POINTER(M1_PTR   , M1%R4  , ARRAYSHAPE_WX)
CALL C_F_POINTER(M10_PTR  , M10%R4 , ARRAYSHAPE_WX)
CALL C_F_POINTER(M100_PTR , M100%R4, ARRAYSHAPE_WX)
CALL C_F_POINTER(MLH_PTR  , MLH%R4 , ARRAYSHAPE_WX)
CALL C_F_POINTER(MLW_PTR  , MLW%R4 , ARRAYSHAPE_WX)
CALL C_F_POINTER(MFOL_PTR , MFOL%R4, ARRAYSHAPE_WX)

IF (USE_ERC) THEN
   CALL C_F_POINTER(ERC_PTR   , ERC%R4    , ARRAYSHAPE_WX)
   CALL C_F_POINTER(IGNFAC_PTR, IGNFAC%R4 , ARRAYSHAPE_WX)
ENDIF

IF (USE_IGNITION_MASK) CALL C_F_POINTER(IGN_MASK_PTR          , IGN_MASK%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(ASP_PTR          , ASP%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(CBH_PTR          , CBH%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(CBD_PTR          , CBD%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(CC_PTR           , CC%R4         , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(CH_PTR           , CH%R4         , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
IF (MODE .NE. 2) CALL C_F_POINTER(DEM_PTR          , DEM%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(FBFM_PTR         , FBFM%I2      , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(SLP_PTR          , SLP%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(ADJ_PTR          , ADJ%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
IF (MODE .NE. 2) CALL C_F_POINTER(PHI0_PTR         , PHI0%R4       , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(WAF_PTR          , WAF%R4        , ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(OMCOSSLPRAD_PTR  , OMCOSSLPRAD%R4, ARRAYSHAPE_ANALYSIS_SINGLEBAND )
CALL C_F_POINTER(ISNONBURNABLE_PTR, ISNONBURNABLE  , ARRAYSHAPE_ISNONBURNABLE       )
IF (USE_POPULATION_DENSITY) CALL C_F_POINTER(POPULATION_DENSITY_PTR, POPULATION_DENSITY%R4 , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
IF (USE_REAL_ESTATE_VALUE ) CALL C_F_POINTER(REAL_ESTATE_VALUE_PTR , REAL_ESTATE_VALUE%R4  , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
IF (USE_LAND_VALUE        ) CALL C_F_POINTER(LAND_VALUE_PTR        , LAND_VALUE%R4         , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
IF (USE_SDI               ) CALL C_F_POINTER(SDI_PTR               , SDI%R4                , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
IF (USE_HAMADA) THEN
   CALL C_F_POINTER(HAMADA_A_PTR , HAMADA_A%R4 , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
   CALL C_F_POINTER(HAMADA_D_PTR , HAMADA_D%R4 , ARRAYSHAPE_ANALYSIS_SINGLEBAND)
   CALL C_F_POINTER(HAMADA_FB_PTR, HAMADA_FB%R4, ARRAYSHAPE_ANALYSIS_SINGLEBAND)
ENDIF
IF (USE_PYROMES) CALL C_F_POINTER(PYROMES_PTR, PYROMES%I2, ARRAYSHAPE_ANALYSIS_SINGLEBAND)

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)
IF (NPROC .GT. 1) THEN
   CALL MPI_WIN_FENCE(0, WIN_WS  , IERR)
   CALL MPI_WIN_FENCE(0, WIN_WD  , IERR)
   CALL MPI_WIN_FENCE(0, WIN_M1  , IERR)
   CALL MPI_WIN_FENCE(0, WIN_M10 , IERR)
   CALL MPI_WIN_FENCE(0, WIN_M100, IERR)
   CALL MPI_WIN_FENCE(0, WIN_MLH , IERR)
   CALL MPI_WIN_FENCE(0, WIN_MLW , IERR)
   CALL MPI_WIN_FENCE(0, WIN_MFOL, IERR)

   IF (USE_ERC) THEN
      CALL MPI_WIN_FENCE(0, WIN_ERC   , IERR)
      CALL MPI_WIN_FENCE(0, WIN_IGNFAC, IERR)
   ENDIF
   IF (USE_IGNITION_MASK) CALL MPI_WIN_FENCE(0, WIN_IGN_MASK           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_CBH           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_CBD           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_CC            , IERR)
   CALL MPI_WIN_FENCE(0, WIN_CH            , IERR)
   IF (MODE .NE. 2) CALL MPI_WIN_FENCE(0, WIN_DEM           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_FBFM          , IERR)
   CALL MPI_WIN_FENCE(0, WIN_SLP           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_ADJ           , IERR)
   IF (MODE .NE. 2) CALL MPI_WIN_FENCE(0, WIN_PHI0          , IERR)
   CALL MPI_WIN_FENCE(0, WIN_WAF           , IERR)
   CALL MPI_WIN_FENCE(0, WIN_OMCOSSLPRAD   , IERR)
   CALL MPI_WIN_FENCE(0, WIN_ISNONBURNABLE , IERR)

   IF (USE_POPULATION_DENSITY) CALL MPI_WIN_FENCE(0, WIN_POPULATION_DENSITY, IERR)
   IF (USE_REAL_ESTATE_VALUE ) CALL MPI_WIN_FENCE(0, WIN_REAL_ESTATE_VALUE , IERR)
   IF (USE_LAND_VALUE        ) CALL MPI_WIN_FENCE(0, WIN_LAND_VALUE        , IERR)
   IF (USE_SDI               ) CALL MPI_WIN_FENCE(0, WIN_SDI               , IERR)
   IF (USE_PYROMES           ) CALL MPI_WIN_FENCE(0, WIN_PYROMES           , IERR)

ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

! *****************************************************************************
END SUBROUTINE SETUP_SHARED_MEMORY_1
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SETUP_SHARED_MEMORY_2
! *****************************************************************************

INTEGER :: IERR

IF (IRANK_HOST .EQ. 0) THEN
   WRITE(*,*) 'Setting up statistics arrays'
   STATS_SIZE=INT(NUM_CASES_TOTAL,MPI_ADDRESS_KIND)*4_MPI_ADDRESS_KIND   
ELSE
   STATS_SIZE=0_MPI_ADDRESS_KIND
ENDIF

CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_X_PTR                         , WIN_STATS_X                          )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_Y_PTR                         , WIN_STATS_Y                          )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_PROB_PTR                      , WIN_STATS_PROB                       )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_SURFACE_FIRE_AREA_PTR         , WIN_STATS_SURFACE_FIRE_AREA          )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_CROWN_FIRE_AREA_PTR           , WIN_STATS_CROWN_FIRE_AREA            )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_FIRE_VOLUME_PTR               , WIN_STATS_FIRE_VOLUME                )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_AFFECTED_POPULATION_PTR       , WIN_STATS_AFFECTED_POPULATION        )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_AFFECTED_REAL_ESTATE_VALUE_PTR, WIN_STATS_AFFECTED_REAL_ESTATE_VALUE )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_AFFECTED_LAND_VALUE_PTR       , WIN_STATS_AFFECTED_LAND_VALUE        )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_FINAL_CONTAINMENT_FRAC_PTR    , WIN_STATS_FINAL_CONTAINMENT_FRAC     )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_NEMBERS_PTR                   , WIN_STATS_NEMBERS        )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_IWX_BAND_START_PTR            , WIN_STATS_IWX_BAND_START             )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_IWX_SERIAL_BAND_PTR           , WIN_STATS_IWX_SERIAL_BAND            )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_SIMULATION_TSTOP_HOURS_PTR    , WIN_STATS_SIMULATION_TSTOP_HOURS     )
CALL MPI_WIN_ALLOCATE_SHARED (STATS_SIZE, DISP_UNIT, MPI_INFO_NULL, MPI_COMM_HOST, STATS_WALL_CLOCK_TIME_PTR           , WIN_STATS_WALL_CLOCK_TIME            )

IF (IRANK_HOST .NE. 0) THEN
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_X                         , 0, STATS_SIZE, DISP_UNIT, STATS_X_PTR                          )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_Y                         , 0, STATS_SIZE, DISP_UNIT, STATS_Y_PTR                          )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_PROB                      , 0, STATS_SIZE, DISP_UNIT, STATS_PROB_PTR                       )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_SURFACE_FIRE_AREA         , 0, STATS_SIZE, DISP_UNIT, STATS_SURFACE_FIRE_AREA_PTR          )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_CROWN_FIRE_AREA           , 0, STATS_SIZE, DISP_UNIT, STATS_CROWN_FIRE_AREA_PTR            )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_FIRE_VOLUME               , 0, STATS_SIZE, DISP_UNIT, STATS_FIRE_VOLUME_PTR                )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_AFFECTED_POPULATION       , 0, STATS_SIZE, DISP_UNIT, STATS_AFFECTED_POPULATION_PTR        )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_AFFECTED_REAL_ESTATE_VALUE, 0, STATS_SIZE, DISP_UNIT, STATS_AFFECTED_REAL_ESTATE_VALUE_PTR )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_AFFECTED_LAND_VALUE       , 0, STATS_SIZE, DISP_UNIT, STATS_AFFECTED_LAND_VALUE_PTR        )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_FINAL_CONTAINMENT_FRAC    , 0, STATS_SIZE, DISP_UNIT, STATS_FINAL_CONTAINMENT_FRAC_PTR     )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_NEMBERS                   , 0, STATS_SIZE, DISP_UNIT, STATS_NEMBERS_PTR                    )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_IWX_BAND_START            , 0, STATS_SIZE, DISP_UNIT, STATS_IWX_BAND_START_PTR             )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_IWX_SERIAL_BAND           , 0, STATS_SIZE, DISP_UNIT, STATS_IWX_SERIAL_BAND_PTR            )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_SIMULATION_TSTOP_HOURS    , 0, STATS_SIZE, DISP_UNIT, STATS_SIMULATION_TSTOP_HOURS_PTR     )
   CALL MPI_WIN_SHARED_QUERY (WIN_STATS_WALL_CLOCK_TIME           , 0, STATS_SIZE, DISP_UNIT, STATS_WALL_CLOCK_TIME_PTR            )
ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

ARRAYSHAPE_STATS=(/ NUM_CASES_TOTAL /)
CALL C_F_POINTER(STATS_X_PTR                           , STATS_X                          , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_Y_PTR                           , STATS_Y                          , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_PROB_PTR                        , STATS_PROB                       , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_SURFACE_FIRE_AREA_PTR           , STATS_SURFACE_FIRE_AREA          , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_CROWN_FIRE_AREA_PTR             , STATS_CROWN_FIRE_AREA            , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_FIRE_VOLUME_PTR                 , STATS_FIRE_VOLUME                , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_AFFECTED_POPULATION_PTR         , STATS_AFFECTED_POPULATION        , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_AFFECTED_REAL_ESTATE_VALUE_PTR  , STATS_AFFECTED_REAL_ESTATE_VALUE , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_AFFECTED_LAND_VALUE_PTR         , STATS_AFFECTED_LAND_VALUE        , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_FINAL_CONTAINMENT_FRAC_PTR      , STATS_FINAL_CONTAINMENT_FRAC     , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_NEMBERS_PTR                     , STATS_NEMBERS                    , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_IWX_BAND_START_PTR              , STATS_IWX_BAND_START             , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_IWX_SERIAL_BAND_PTR             , STATS_IWX_SERIAL_BAND            , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_SIMULATION_TSTOP_HOURS_PTR      , STATS_SIMULATION_TSTOP_HOURS     , ARRAYSHAPE_STATS )
CALL C_F_POINTER(STATS_WALL_CLOCK_TIME_PTR             , STATS_WALL_CLOCK_TIME            , ARRAYSHAPE_STATS )

STATS_X(:) = 0.
STATS_Y(:) = 0.
STATS_PROB(:) = 0.
STATS_SURFACE_FIRE_AREA(:) = 0.
STATS_CROWN_FIRE_AREA(:) = 0.
STATS_FIRE_VOLUME(:) = 0.
STATS_AFFECTED_POPULATION(:) = 0.
STATS_AFFECTED_REAL_ESTATE_VALUE(:) = 0.
STATS_AFFECTED_LAND_VALUE(:) = 0.
STATS_FINAL_CONTAINMENT_FRAC(:) = -9999.
STATS_NEMBERS(:) = 0.
STATS_IWX_BAND_START(:) = 0
STATS_IWX_SERIAL_BAND(:) = 0
STATS_SIMULATION_TSTOP_HOURS(:) = 0.
STATS_WALL_CLOCK_TIME(:) = 0.

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

IF (NPROC .GT. 1) THEN
   CALL MPI_WIN_FENCE(0, WIN_STATS_X                          , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_Y                          , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_PROB                       , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_SURFACE_FIRE_AREA          , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_CROWN_FIRE_AREA            , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_FIRE_VOLUME                , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_AFFECTED_POPULATION        , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_AFFECTED_REAL_ESTATE_VALUE , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_AFFECTED_LAND_VALUE        , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_FINAL_CONTAINMENT_FRAC     , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_NEMBERS                    , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_IWX_BAND_START             , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_IWX_SERIAL_BAND            , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_SIMULATION_TSTOP_HOURS     , IERR)
   CALL MPI_WIN_FENCE(0, WIN_STATS_WALL_CLOCK_TIME            , IERR)
ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

! *****************************************************************************
END SUBROUTINE SETUP_SHARED_MEMORY_2
! *****************************************************************************

! *****************************************************************************
SUBROUTINE CALC_WIND_ADJUSTMENT_FACTOR_EVERYWHERE(CC, CH, FBFM, WAF)
! *****************************************************************************
!USE ELMFIRE_IO, ONLY : WRITE_BIL_RASTER_ONEBAND
TYPE(RASTER_TYPE), INTENT(IN) :: CC, CH, FBFM
TYPE(RASTER_TYPE), INTENT(INOUT) :: WAF
REAL :: F, SHELTERED_WAF, UNSHELTERED_WAF, UNSHELTERED_FRAC

INTEGER :: IROW, ICOL, ICC, ICH
!CHARACTER(400) :: OUTPUT_DIRECTORY, OUTPUT_FILENAME

WAF%BYTEORDER     = ADJ%BYTEORDER
WAF%LAYOUT        = ADJ%LAYOUT
WAF%NROWS         = ADJ%NROWS
WAF%NCOLS         = ADJ%NCOLS
WAF%NBANDS        = ADJ%NBANDS
WAF%NBITS         = ADJ%NBITS
WAF%BANDROWBYTES  = ADJ%BANDROWBYTES
WAF%TOTALROWBYTES = ADJ%TOTALROWBYTES
WAF%PIXELTYPE     = ADJ%PIXELTYPE
WAF%ULXMAP        = ADJ%ULXMAP
WAF%ULYMAP        = ADJ%ULYMAP
WAF%XDIM          = ADJ%XDIM
WAF%YDIM          = ADJ%YDIM
WAF%NODATA_VALUE  = ADJ%NODATA_VALUE
WAF%CELLSIZE      = ADJ%CELLSIZE
WAF%XLLCORNER     = ADJ%XLLCORNER
WAF%YLLCORNER     = ADJ%YLLCORNER

!DO IROW = 1, WAF%NROWS
!DO ICOL = 1, WAF%NCOLS
!   IF (CC%R4(ICOL,IROW,1) .LT. 0.) THEN
!      WAF%R4(ICOL,IROW,1) = 0.
!   ELSE
!      F = 0.3333 * CC%R4(ICOL,IROW,1) * CROWN_RATIO
!      IF (F .GT. 0.05) THEN ! Use sheltered WAF
!         ICC = MIN(MAX(NINT(CC%R4(ICOL,IROW,1)*100.),0),100)
!         ICH = MIN(MAX(NINT(CH%R4(ICOL,IROW,1)     ),0),120)
!         WAF%R4(ICOL,IROW,1) = SHELTERED_WAF_TABLE(ICC,ICH)
!      ELSE ! Use unsheltered WAF
!         WAF%R4(ICOL,IROW,1) = FUEL_MODEL_TABLE_2D(MAX(FBFM%I2(ICOL,IROW,1),0),30)%UNSHELTERED_WAF
!      ENDIF
!   ENDIF
!ENDDO
!ENDDO

DO IROW = 1, WAF%NROWS
DO ICOL = 1, WAF%NCOLS
   IF (CC%R4(ICOL,IROW,1) .LT. 0.) THEN
      WAF%R4(ICOL,IROW,1) = 0.
   ELSE
      UNSHELTERED_WAF = FUEL_MODEL_TABLE_2D(MAX(FBFM%I2(ICOL,IROW,1),0),30)%UNSHELTERED_WAF

      ICC = MIN(MAX(NINT(CC%R4(ICOL,IROW,1)*100.),0),100)
      ICH = MIN(MAX(NINT(CH%R4(ICOL,IROW,1)     ),0),120)
      SHELTERED_WAF = SHELTERED_WAF_TABLE(ICC,ICH)
      SHELTERED_WAF = MIN(SHELTERED_WAF, UNSHELTERED_WAF)

      F = 0.3333 * CC%R4(ICOL,IROW,1) * CROWN_RATIO

      IF (F .GE. 0.05) THEN
         WAF%R4(ICOL,IROW,1) = SHELTERED_WAF
      ELSE
         UNSHELTERED_FRAC = 1.0 - 20. * F
         WAF%R4(ICOL,IROW,1) = UNSHELTERED_FRAC * UNSHELTERED_WAF + (1. - UNSHELTERED_FRAC) * SHELTERED_WAF
      ENDIF
   ENDIF
ENDDO
ENDDO

!OUTPUT_DIRECTORY='./'
!OUTPUT_FILENAME='test'
!CALL WRITE_BIL_RASTER_ONEBAND(WAF, OUTPUT_DIRECTORY, OUTPUT_FILENAME, .FALSE., .FALSE. )

! *****************************************************************************
END SUBROUTINE CALC_WIND_ADJUSTMENT_FACTOR_EVERYWHERE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE ROTATE_ASP_AND_WD (ITYPE)
! *****************************************************************************

INTEGER, INTENT(IN) :: ITYPE
INTEGER :: IBAND, IROW, ICOL

SELECT CASE (ITYPE)
   CASE (1) ! Aspect
      CONTINUE 
   CASE (2) ! Wind direction
      DO IBAND = 1, WD%NBANDS
      DO IROW = 1, WD%NROWS
      DO ICOL = 1, WD%NCOLS
         WD%R4(ICOL,IROW,IBAND) = WD%R4(ICOL,IROW,IBAND) - GRID_DECLINATION
         IF (WD%R4(ICOL,IROW,IBAND) .GT. 360.) WD%R4(ICOL,IROW,IBAND) = WD%R4(ICOL,IROW,IBAND) - 360.
         IF (WD%R4(ICOL,IROW,IBAND) .LT.   0.) WD%R4(ICOL,IROW,IBAND) = WD%R4(ICOL,IROW,IBAND) + 360.
         CONTINUE
      ENDDO
      ENDDO
      ENDDO
END SELECT

! *****************************************************************************
END SUBROUTINE ROTATE_ASP_AND_WD
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION CALC_WIND_ADJUSTMENT_FACTOR_SINGLE(CC, CH, FUEL_BED_HEIGHT)
! *****************************************************************************

REAL, INTENT(IN) :: CC, CH, FUEL_BED_HEIGHT

REAL :: HFT, NUMER, DENOM, UHOU20PH, F, UCOUH, HFOH, TERM1, TERM2

IF (CC .LT. 0.) THEN
   CALC_WIND_ADJUSTMENT_FACTOR_SINGLE = 0.
ELSE
   IF (CC .GT. 1E-4 .AND. CH .GT. 1E-4) THEN !Canopy is present
      HFT = CH / 0.3048 
      NUMER = 20. + 0.36*HFT
      DENOM = 0.13 * HFT
      UHOU20PH = 1. / LOG(NUMER/DENOM)
      F = 0.3333 * CC * CROWN_RATIO !Same as BEHAVE
      UCOUH = 0.555 / SQRT(F * HFT)
      CALC_WIND_ADJUSTMENT_FACTOR_SINGLE = UHOU20PH * UCOUH
   ELSE !Canopy is not present
      IF (FUEL_BED_HEIGHT .GT. 1E-4) THEN
         HFOH = 1.0 ! Same as BEHAVE and FARSITE
         HFT = FUEL_BED_HEIGHT
         NUMER = 20. + 0.36*HFT
         DENOM = 0.13 * HFT
         TERM1 = (1. + 0.36/HFOH) / LOG(NUMER/DENOM)
         NUMER = HFOH + 0.36
         TERM2 = LOG(NUMER/0.13) - 1.
         CALC_WIND_ADJUSTMENT_FACTOR_SINGLE = TERM1 * TERM2       
      ELSE
         CALC_WIND_ADJUSTMENT_FACTOR_SINGLE = 0.
      ENDIF
   ENDIF
ENDIF

CONTINUE

! *****************************************************************************
END FUNCTION CALC_WIND_ADJUSTMENT_FACTOR_SINGLE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE READ_FUEL_MODEL_TABLE
! *****************************************************************************

CHARACTER(400) :: FNINPUT
INTEGER :: I, INUM, IOS, ILH
REAL :: LIVEFRAC, DEADFRAC, LH, WSMFEFF, LOW, PHIMAG
INTEGER, PARAMETER :: NUM_FUEL_MODELS = 303
TYPE(FUEL_MODEL_TABLE_TYPE) :: FM

TYPE(FUEL_MODEL_TABLE_TYPE), ALLOCATABLE, DIMENSION(:) :: FUEL_MODEL_TABLE

ALLOCATE(FUEL_MODEL_TABLE(0:NUM_FUEL_MODELS))

FUEL_MODEL_TABLE(:)%SHORTNAME='NULL' !Initialize fuel model names

FNINPUT = TRIM(MISCELLANEOUS_INPUTS_DIRECTORY) // TRIM(FUEL_MODEL_FILE)

!Attempt to open fuel model table file:
OPEN(LUINPUT,FILE=TRIM(FNINPUT),FORM='FORMATTED',STATUS='OLD',IOSTAT=IOS)
IF (IOS .GT. 0) THEN
   WRITE(*,*) 'Problem opening fuel model table file ', TRIM(FNINPUT)
   STOP
ENDIF

!Read fuel models and store in FUEL_MODEL_TABLE
IOS = 0
DO WHILE (IOS .EQ. 0)
   READ(LUINPUT,*,IOSTAT=IOS) INUM,FM%SHORTNAME,FM%DYNAMIC,FM%W0(1),FM%W0(2),FM%W0(3),FM%W0(5), &
                                FM%W0(6),FM%SIG(1),FM%SIG(5),FM%SIG(6),FM%DELTA,FM%MEX_DEAD,FM%HOC
   FM%MEX_DEAD = FM%MEX_DEAD / 100.
   FM%SIG(2) = 109.  !  10-hour surface area to volume ratio, 1/ft
   FM%SIG(3) =  30.  ! 100-hour surface area to volume ratio, 1/ft
   FM%RHOP   =  32.  ! Particle density
   FM%ST     =   0.055
   FM%SE     =   0.01
   FM%ETAS   = 0.174/(FM%SE**0.19) !Mineral damping coefficient, dimensionless

   IF (IOS .EQ. 0) FUEL_MODEL_TABLE(INUM) = FM
ENDDO
CLOSE(LUINPUT)

DO INUM = 0, NUM_FUEL_MODELS
   IF ( TRIM(FUEL_MODEL_TABLE(INUM)%SHORTNAME) .EQ. 'NULL' ) CYCLE
   FUEL_MODEL_TABLE_2D(INUM,:) = FUEL_MODEL_TABLE(INUM)

   DO ILH = 30, 120
      LH = REAL(ILH)
      FM = FUEL_MODEL_TABLE_2D(INUM,ILH)

      IF (FM%DYNAMIC) THEN
         LIVEFRAC  = MIN( MAX( (LH - 30. ) / (120.  - 30. ) , 0.), 1.)
         DEADFRAC  = 1. - LIVEFRAC
         FM%W0 (4) = DEADFRAC * FM%W0(5)
         FM%W0 (5) = LIVEFRAC * FM%W0(5)
         FM%SIG(4) = FM%SIG(5)
         FM%SIG(1) = (FM%SIG(1)*FM%SIG(1)*FM%W0(1) + FM%SIG(4)*FM%SIG(4)*FM%W0(4)) / ( FM%SIG(1)*FM%W0(1) + FM%SIG(4)*FM%W0(4) )
         FM%W0 (1) = FM%W0(1) + FM%W0(4)
         FM%W0 (4) = 0.
         FM%SIG(4) = 9999.
      ELSE
         FM%W0 (4) = 0.0
         FM%SIG(4) = 9999.
      ENDIF
   
      FM%A(:) = FM%SIG(:)*FM%W0(:) / FM%RHOP

      FM%A_DEAD = MAX(SUM(FM%A(1:4)),1E-9)
      FM%A_LIVE = MAX(SUM(FM%A(5:6)),1E-9)
      FM%A_OVERALL = FM%A_DEAD + FM%A_LIVE

      FM%F   (1:4) = FM%A(1:4) / FM%A_DEAD
      FM%FMEX(1:4) = FM%F(1:4) * FM%MEX_DEAD
      FM%F   (5:6) = FM%A(5:6) / FM%A_LIVE 
   
      FM%F_DEAD = FM%A_DEAD / FM%A_OVERALL
      FM%F_LIVE = FM%A_LIVE / FM%A_OVERALL

      FM%FW0(:) = FM%F(:) * FM%W0(:)
   
      FM%FSIG(:) = FM%F(:) * FM%SIG(:)

      FM%EPS(:) = EXP(-138. / FM%SIG(:))

      FM%FEPS(:) = FM%F(:) * FM%EPS(:)

      FM%WPRIMENUMER(1:4) = FM%W0(1:4) * FM%EPS(1:4)
      FM%WPRIMEDENOM(5:6) = FM%W0(5:6) * EXP(-500./FM%SIG(5:6))

      FM%MPRIMEDENOM(1:4) = FM%W0(1:4) * FM%EPS(1:4)
   
      FM%W0_DEAD = SUM(FM%FW0(1:4))
      FM%W0_LIVE = SUM(FM%FW0(5:6))
   
      FM%WN_DEAD = FM%W0_DEAD * (1. - FM%ST)
      FM%WN_LIVE = FM%W0_LIVE * (1. - FM%ST)
      
      FM%SIG_DEAD = SUM(FM%FSIG(1:4))
      FM%SIG_LIVE = SUM(FM%FSIG(5:6))
  
      FM%SIG_OVERALL = FM%F_DEAD * FM%SIG_DEAD + FM%F_LIVE * FM%SIG_LIVE
      FM%BETA        = SUM(FM%W0(1:6)) / (FM%DELTA * FM%RHOP)
      FM%BETAOP      = 3.348/(FM%SIG_OVERALL**0.8189)
      FM%RHOB        = SUM(FM%W0(1:6)) / FM%DELTA
   
      FM%XI = EXP((0.792 + 0.681*SQRT(FM%SIG_OVERALL))*(0.1+FM%BETA)) / (192. + 0.2595*FM%SIG_OVERALL)
   
      FM%A_COEFF = 133./(FM%SIG_OVERALL**0.7913)
      FM%B_COEFF = 0.02526*FM%SIG_OVERALL**0.54
      FM%C_COEFF = 7.47*EXP(-0.133*FM%SIG_OVERALL**0.55)
      FM%E_COEFF = 0.715*(EXP(-0.000359*FM%SIG_OVERALL))
   
      FM%GAMMAPRIMEPEAK = FM%SIG_OVERALL**1.5 / (495. + 0.0594*FM%SIG_OVERALL**1.5)
      FM%GAMMAPRIME = FM%GAMMAPRIMEPEAK*(FM%BETA/FM%BETAOP)**FM%A_COEFF*EXP(FM%A_COEFF*(1.-FM%BETA/FM%BETAOP))
   
      FM%TR = 384. / FM%SIG_OVERALL

      FM%GP_WND_EMD_ES_HOC = FM%GAMMAPRIME * FM%WN_DEAD * FM%ETAS * FM%HOC
      FM%GP_WNL_EML_ES_HOC = FM%GAMMAPRIME * FM%WN_LIVE * FM%ETAS * FM%HOC

      FM%PHISTERM=5.275 * FM%BETA**(-0.3)
      FM%PHIWTERM = FM%C_COEFF * (FM%BETA / FM%BETAOP)**(-FM%E_COEFF)

      FM%B_COEFF_INVERSE = 1. / FM%B_COEFF
      FM%WSMFEFF_COEFF = (1. / FM%PHIWTERM) ** FM%B_COEFF_INVERSE

      FM%WPRIMEDENOM56SUM = SUM(FM%WPRIMEDENOM(5:6))
      FM%WPRIMENUMER14SUM = SUM(FM%WPRIMENUMER(1:4))
      FM%MPRIMEDENOM14SUM = SUM(FM%MPRIMEDENOM(1:4))

      FM%R_MPRIMEDENOME14SUM_MEX_DEAD = 1. / (FM%MPRIMEDENOM14SUM * FM%MEX_DEAD)

      FM%UNSHELTERED_WAF = CALC_WIND_ADJUSTMENT_FACTOR_SINGLE(0., 0., FM%DELTA)

      IF (FM%WPRIMEDENOM56SUM .GT. 1E-6) THEN
         FM%MEX_LIVE = 2.9 * FM%WPRIMENUMER14SUM / FM%WPRIMEDENOM56SUM
      ELSE
         FM%MEX_LIVE = 100.0
      ENDIF

      FUEL_MODEL_TABLE_2D(INUM,ILH) = FM

   ENDDO

ENDDO

!Set any unused fuel models to 256 (NB)
DO INUM = 0, NUM_FUEL_MODELS
DO ILH = 30, 120
   IF ( TRIM(FUEL_MODEL_TABLE_2D(INUM,ILH)%SHORTNAME) .EQ. 'NULL' ) FUEL_MODEL_TABLE_2D(INUM,ILH) = FUEL_MODEL_TABLE(256)
ENDDO
ENDDO

! Build lookup tables:
IF (.NOT. ALLOCATED(LOW_FROM_WSMFEFF)) THEN 
   ALLOCATE(LOW_FROM_WSMFEFF(0:100000))
   ALLOCATE(BOH_FROM_LOW    (0:20000))
   ALLOCATE(WSMFEFF_FROM_FBFM_AND_PHIMAG(0:NUM_FUEL_MODELS,0:10000))

   LOW_FROM_WSMFEFF(0) = 1E0
   DO I = 1, 100000
      WSMFEFF=REAL(I) * 0.1
      LOW_FROM_WSMFEFF(I)=MIN( 0.936*EXP(0.2566*WSMFEFF*60./5280.) + 0.461*EXP(-0.1548*WSMFEFF*60.0/5280.) - 0.397, MAX_LOW)
   ENDDO

   BOH_FROM_LOW(0:1000) = 1.
   DO I = 1001, 20000
      LOW = REAL(I) * 0.001
      BOH_FROM_LOW(I)= 1.0 / ((LOW + SQRT(LOW*LOW - 1.0)) / (LOW - SQRT(LOW*LOW -1.0)))
   ENDDO

   DO INUM = 0, NUM_FUEL_MODELS
      IF (FUEL_MODEL_TABLE_2D(INUM,30)%B_COEFF_INVERSE .GT. 1E-3) THEN
         DO I = 0, 10000
            PHIMAG = REAL(I) * 0.01
            WSMFEFF_FROM_FBFM_AND_PHIMAG(INUM,I) = FUEL_MODEL_TABLE_2D(INUM,30)%WSMFEFF_COEFF * PHIMAG ** FUEL_MODEL_TABLE_2D(INUM,30)%B_COEFF_INVERSE
         ENDDO
      ENDIF
   ENDDO

   DO I = 1, NUM_FUEL_MODELS
      WSMFEFF_COEFF  (I) = FUEL_MODEL_TABLE_2D(I,30)%WSMFEFF_COEFF
      B_COEFF_INVERSE(I) = FUEL_MODEL_TABLE_2D(I,30)%B_COEFF_INVERSE
      TR             (I) = FUEL_MODEL_TABLE_2D(I,30)%TR
   ENDDO   

ENDIF

! *****************************************************************************
END SUBROUTINE READ_FUEL_MODEL_TABLE
! *****************************************************************************

END MODULE