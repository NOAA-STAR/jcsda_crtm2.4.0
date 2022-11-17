!----------------------------------------------------------------------------------
!:sdoc+:
!
! CSEM_SnowMW_SfcOptics
!
! Module to compute the surface optical properties of Snow surfaces at microwave
! frequencies, which is required for determining the surface contribution
! to the overall radiative transfer. 
!
! This module provide a general container for developers to integrate individual 
! models into the model repository, and a generic interface for 
! the upper-level applications to access the model options in the repository.
 
! This module implementes the FWD, TL and AD functions for variational data 
! assimilation application and retrieval applications. It replacess the similar
! functions as those in the original CRTM surface module "CRTM_SnowMW_SfcOptics", 
! which was Written by Paul van Delst, 23-Jun-2005
!
!
! CREATION HISTORY:
!       Written by:     Ming Chen, 28-Feb-2016
!                       ming.chen@noaa.gov
!
!:sdoc-:
!-----------------------------------------------------------------------------------------------

MODULE CSEM_SnowMW_SfcOptics
  ! -----------------
  ! Environment setup
  ! -----------------
  ! Module use
  USE CSEM_Type_Kinds, ONLY: fp => CSEM_fp
  USE CSEM_Exception_Handler
  USE CSEM_Define
  USE CSEM_Model_Manager

  USE NESDIS_SnowMW_PhyModel
  USE NESDIS_Sensors_SnowMW_Modules

! Disable implicit typing
  IMPLICIT NONE


  ! ------------
  ! Visibilities
  ! ------------
  ! Everything private by default
  PRIVATE
  ! Data types
  ! Science routines
  PUBLIC :: CSEM_Compute_SnowMW_SfcOptics
  PUBLIC :: CSEM_Compute_SnowMW_SfcOptics_TL
  PUBLIC :: CSEM_Compute_SnowMW_SfcOptics_AD
  PUBLIC :: iVar_type
  
  REAL(fp), PARAMETER ::  ONE = 1.0_fp, ZERO = 0.0_fp
  ! --------------------------------------
  ! Structure definition to hold forward
  ! variables across FWD, TL, and AD calls
  ! --------------------------------------
  TYPE :: iVar_type
    PRIVATE
    INTEGER :: Dummy = 0
  END TYPE iVar_type

  TYPE(CSEM_MODEL_ID), SAVE  :: MODEL

CONTAINS

!----------------------------------------------------------------------------------
!:sdoc+:
!
! NAME:
!       CSEM_Compute_SnowMW_SfcOptics
!
! PURPOSE:
!       Function to compute the surface emissivity and reflectivity at Infrared
!       frequencies over a Snow surface.
!
!       This function is a wrapper for third party code.
!
! PURPOSE:
!       Function to compute the surface emissivity  at Infrared
!       frequencies over a Snow surface.
!
!       This function encapsulates all available  CSEM SnowMW emissivity models,and
!       provides a genereic interface for the upper-level user application.
!
! CALLING SEQUENCE:
!       IO_Status = CSEM_Compute_SnowMW_SfcOptics( 
!                                        Surface                  ,&  ! Input
!                                        SfcOptics                ,&  ! Output
!                                        Options )                    ! Input 
!
! INPUTS:
!
!       Surface:         CSEM Snow Surface structure containing the surface state
!                        inputs.
!                        UNITS:      N/A
!                        TYPE:       CSEM_Snow_Surface
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN)
!
!       Options:         CSEM input extension structure containing additional inputs,
!                        e.g., Gelocation/Time Metadata,  Sensor observations, et al,
!                        which may be used by emprirical and semi-empirical models.
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN)
!
!
! OUTPUTS:
!       SfcOptics:       CSEM output structure containing the surface optical
!                        properties required for the radiative transfer calculation,
!                        including wavelength and geometry structure as the inputs
!                        UNITS:      N/A
!                        TYPE:       CSEM_SfcOptics_Type
!                        DIMENSION:  Assumed-shape Array
!                        ATTRIBUTES: INTENT(IN OUT)
! FUNCTION RESULT:
!       IO_Status:    The return value is an integer defining the error status.
!                        The error codes are defined in the CSEM_Exception_Handler module.
!                        If == SUCCESS the computation was sucessful
!                           == FAILURE an unrecoverable error occurred
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!
!
! COMMENTS:
!                       CSEM infrastructure data structures are defined in CSEM_DEFINE.f90
!       
!
!:sdoc-:
!-----------------------------------------------------------------------------------------------

  FUNCTION CSEM_Compute_SnowMW_SfcOptics(  &
      Surface,                             &  ! Input
      SfcOptics,                           &  ! Output
      Options)                             &  !  Input
    RESULT (IO_Status)

    TYPE(CSEM_Snow_Surface),   INTENT(IN)    :: Surface
    TYPE(CSEM_SfcOptics_Type), INTENT(INOUT) :: SfcOptics
    TYPE(CSEM_Options_Type),   INTENT(IN)    :: Options
    ! Function result
    INTEGER ::  IO_Status
 

    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CSEM_Compute_SnowMW_SfcOptics'
 
    ! Local parameters
    REAL(fp), PARAMETER :: FREQUENCY_THRESHOLD   =   80.0_fp  ! GHz
    REAL(fp), PARAMETER :: DEFAULT_EMISSIVITY    =   0.90_fp
    REAL(fp), PARAMETER :: NOT_USED(4)           = -99.9_fp
    INTEGER :: i, n_Angles

    IO_Status  = SUCCESS
    n_Angles =  SfcOptics%n_Angles
    
    SfcOptics%Emissivity = DEFAULT_EMISSIVITY
    SfcOptics%Reflectivity = ZERO

    MODEL = Inq_Model_Option("MW_SNOW") 

    IF(INDEX(TRIM(MODEL%NAME),'SensorBased') > 0 .AND. &
       TRIM(SnowMW_SensorName(Options%SensorObs%Sensor_Id)) .NE.'unknown' ) THEN
       
        IO_Status = CRTM_Sensors_SnowMW_Emiss(  &
                 Surface,                          &  ! Input
                 Options%SensorObs,                   &  ! OptionalInput 
                 SfcOptics)                           ! Output
      
    ELSE
      
       IF ( SfcOptics%Frequency  < FREQUENCY_THRESHOLD  ) THEN
         DO i = 1, n_Angles  
             ! Frequency is low enough for the model
            !IO_Status =  NESDIS_SnowMW_Emiss(&
            !     SfcOptics%Frequency,                 &  ! Input
            !     SfcOptics%Angle(i),                  &  ! Input
            !     Surface%Snow_Temperature,            &  ! Input
            !     Surface%Top_Soil_Temperature,        &  ! Input
            !     Surface%Top_Soil_Moisture_Content,   &  ! Input
            !     Surface%Snow_Depth,                  &  ! Input
            !     Surface%Soil_Type,                   &  ! Input
            !     SfcOptics%Emissivity(i,2),           &  ! Output
            !     SfcOptics%Emissivity(i,1) )             ! Output

             CALL NESDIS_SnowMW_Emiss(&           
                           SfcOptics%Angle(i),            &   ! Input
                           SfcOptics%Frequency,           &   ! Input
                           NOT_USED(1),                   &   ! Input
                           NOT_USED(1),                   &   ! Input
                           Surface%Snow_Temperature,      &   ! Input
                           Surface%Snow_Temperature,      &   ! Input
                           Surface%Lai,                   &   ! Input
                           Surface%Soil_Type,             &   ! Input
                           Surface%Vegetation_Type,       &   ! Input
                           Surface%Snow_depth,            &   ! Input
                           SfcOptics%Emissivity(i,2),     &   ! Output
                           SfcOptics%Emissivity(i,1) )              ! Output
 
          END DO
        ELSE
          SfcOptics%Emissivity(1:SfcOptics%n_Angles,1:2) = DEFAULT_EMISSIVITY

        END IF
    END IF
    
   IO_Status  = SUCCESS
   
   SfcOptics%Reflectivity = ZERO
   DO i = 1, n_Angles  
      SfcOptics%Reflectivity(i,1,i,1) = ONE-SfcOptics%Emissivity(i,1)
      SfcOptics%Reflectivity(i,2,i,2) = ONE-SfcOptics%Emissivity(i,2)
    END DO

  END FUNCTION CSEM_Compute_SnowMW_SfcOptics

!----------------------------------------------------------------------------------
!:sdoc+:
!
! NAME:
!       CSEM_Compute_SnowMW_SfcOptics_TL
!
! PURPOSE:
!       Function to compute the tangent-linear surface emissivity and
!       reflectivity at microwave frequencies over a Snow surface.
!
!       This function is a wrapper for third party code.
!
!
! CALLING SEQUENCE:
!       IO_Status = CSEM_Compute_SnowMW_SfcOptics_TL( SfcOptics_TL )
!
! OUTPUTS:
!     CSEM_SfcOptics_TL: Structure containing the tangent-linear surface
!                        optical properties required for the tangent-
!                        linear radiative transfer calculation.
!                        UNITS:      N/A
!                        TYPE:       CSEM_SfcOptics_Type
!                        DIMENSION:  Assumed-shape Array
!                        ATTRIBUTES: INTENT(IN OUT)
!
! FUNCTION RESULT:
!       IO_Status:    The return value is an integer defining the error status.
!                        The error codes are defined in the Message_Handler module.
!                        If == SUCCESS the computation was sucessful
!                           == FAILURE an unrecoverable error occurred
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!
! COMMENTS:
!       CURRENTLY THIS IS A STUB FUNCTION AS THERE ARE NO TL
!        COMPONENTS IN THE MW Snow SFCOPTICS COMPUTATIONS.
!
!:sdoc-:
!----------------------------------------------------------------------------------
  FUNCTION CSEM_Compute_SnowMW_SfcOptics_TL( &
       CSEM_SfcOptics_TL)                    &  ! TL  Output
    RESULT ( IO_Status )
    
    ! Arguments
    TYPE(CSEM_SfcOptics_Type), INTENT(INOUT)   :: CSEM_SfcOptics_TL
    ! Function result
    INTEGER :: IO_Status
    
    ! Local parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CSEM_Compute_SnowMW_SfcOptics_TL'

    ! Set up
    IO_Status = SUCCESS

    ! Compute the tangent-linear surface optical parameters
    ! ***No TL models yet, so default TL output is zero***
    CSEM_SfcOptics_TL%Reflectivity(:,:,:,:) = ZERO
    CSEM_SfcOptics_TL%Emissivity(:,:)  = ZERO
 
  END FUNCTION CSEM_Compute_SnowMW_SfcOptics_TL


!----------------------------------------------------------------------------------
!:sdoc+:
!
! NAME:
!       CSEM_Compute_SnowMW_SfcOptics_AD
!
! PURPOSE:
!       Function to compute the adjoint surface emissivity and
!       reflectivity at microwave frequencies over a Snow surface.
!
!       This function is a wrapper for third party code.
!
!       NB: CURRENTLY THIS IS A STUB FUNCTION AS THERE ARE NO AD
!           COMPONENTS IN THE MW Snow SFCOPTICS COMPUTATIONS.
!
! CALLING SEQUENCE:
!       IO_Status = CSEM_Compute_SnowMW_SfcOptics_AD( SfcOptics_AD )
!
! INPUTS:
!       CSEM_SfcOptics_AD:    Structure containing the adjoint surface optical
!                        properties required for the adjoint radiative
!                        transfer calculation.
!                        *** COMPONENTS MODIFIED UPON OUTPUT ***
!                        UNITS:      N/A
!                        TYPE:       CSEM_SfcOptics_Type
!                        DIMENSION:  Scalar
!                        ATTRIBUTES: INTENT(IN OUT)
!
! FUNCTION RESULT:
!       IO_Status:    The return value is an integer defining the error status.
!                        The error codes are defined in the Message_Handler module.
!                        If == SUCCESS the computation was sucessful
!                           == FAILURE an unrecoverable error occurred
!                        UNITS:      N/A
!                        TYPE:       INTEGER
!                        DIMENSION:  Scalar
!
! COMMENTS:
!       Note the INTENT on the input adjoint arguments are IN OUT regardless
!       of their specification as "input" or "output". This is because these
!       arguments may contain information on input, or need to be zeroed on
!       output (or both).
!
!:sdoc-:
!----------------------------------------------------------------------------------
  FUNCTION CSEM_Compute_SnowMW_SfcOptics_AD( &
       CSEM_Surface_AD)                      &  ! AD  Input
    RESULT( IO_Status )
    
    ! Arguments
    TYPE(CSEM_Snow_Surface), INTENT(INOUT)   :: CSEM_Surface_AD
    ! Function result
    INTEGER :: IO_Status
    ! Local parameters
    CHARACTER(*), PARAMETER :: ROUTINE_NAME = 'CSEM_Compute_SnowMW_SfcOptics_AD'

    ! Set up
    IO_Status = SUCCESS


    ! Compute the adjoint surface optical parameters
    ! ***No AD models yet, so there is no impact on AD result***
    CSEM_Surface_AD%Snow_Temperature           =  CSEM_Surface_AD%Snow_Temperature     + ZERO
    CSEM_Surface_AD%Snow_Depth                 =  CSEM_Surface_AD%Snow_Depth           + ZERO
    CSEM_Surface_AD%Snow_Density               =  CSEM_Surface_AD%Snow_Density         + ZERO
    CSEM_Surface_AD%Snow_Grain_Size            =  CSEM_Surface_AD%Snow_Grain_Size      + ZERO
    CSEM_Surface_AD%Top_Soil_Temperature       =  CSEM_Surface_AD%Top_Soil_Temperature + ZERO
    CSEM_Surface_AD%Top_Soil_Moisture_Content  =  CSEM_Surface_AD%Top_Soil_Moisture_Content + ZERO

  END FUNCTION CSEM_Compute_SnowMW_SfcOptics_AD

END MODULE CSEM_SnowMW_SfcOptics
