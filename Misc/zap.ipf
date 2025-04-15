#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

Function zapBad(image,DezingerRatio)
	wave image
	variable DezingerRatio               //typically3-5x
	Duplicate/Free image, dup
	MatrixFilter /N=5 median image       // 3x3 median filter (integer result if image integer, fp if fp)
	MatrixOp/Free DiffWave = dup / (abs(image))      // ratio between raw and filtered, high values (>3-5) are comics and high signals  
				//image = SelectNumber(DiffWave>DezingerRatio,dup,image)    // choose filtered (image) if difference is great
	MatrixOp/O image = dup * (-1)*(greater(Diffwave,DezingerRatio)-1) + image*(greater(Diffwave,DezingerRatio))     //the MatrixOp is 3x faster than the line above....
End

Function/WAVE zap(inputWave,thresh) //outputwave,thresh) //, Variable thresh) //removeCosmicRays(inputWave, thresh)
	Wave inputWave //, outputwave
	Variable thresh
	Variable p1,p2,p3, removedCosmicRays = 0
	Duplicate/O/FREE inputWave, outputWave
	Do
		removedCosmicRays = 0
		Variable globalMean = mean(inputWave), globalDeviation = sqrt(variance(inputWave))
		For(p1 = 0; p1 < dimsize(inputWave,0); p1 +=  1)
			For(p2 = 0; p2 < dimsize(inputWave,1); p2 += 1)
				Variable currentPnt, localAverage, localDeviation, currentPntDeviation
				Make/FREE/O/N=9 localPnts
				localPnts[0] = inputWave[mod(p1-1+dimsize(inputWave,0),dimsize(inputWave,0))][p2]
				localPnts[1] = inputWave[p1][mod(p2-1+dimsize(inputWave,1),dimsize(inputWave,1))]
				localPnts[2] = inputWave[mod(p1+1+dimsize(inputWave,0),dimsize(inputWave,0))][p2]
				localPnts[3] = inputWave[p1][mod(p2+1+dimsize(inputWave,1),dimsize(inputWave,1))]	
				localPnts[4] = inputWave[mod(p1-1+dimsize(inputWave,0),dimsize(inputWave,0))][mod(p2+1+dimsize(inputWave,1),dimsize(inputWave,1))]
				localPnts[5] = inputWave[mod(p1-1+dimsize(inputWave,0),dimsize(inputWave,0))][mod(p2-1+dimsize(inputWave,1),dimsize(inputWave,1))]
				localPnts[6] = inputWave[mod(p1+1+dimsize(inputWave,0),dimsize(inputWave,0))][mod(p2+1+dimsize(inputWave,1),dimsize(inputWave,1))]
				localPnts[7] = inputWave[mod(p1+1+dimsize(inputWave,0),dimsize(inputWave,0))][mod(p2-1+dimsize(inputWave,1),dimsize(inputWave,1))]
				localPnts[8] = inputWave[p1][p2]
				localDeviation = sqrt(variance(localPnts))
				If(localDeviation/globalDeviation >= thresh)
					outputWave[p1][p2] = WaveMin(localPnts)
					removedCosmicRays += 1
				endIf
			endFor
		endFor
	p3 += 1
	while((p3 >= 2) ? 0 : removedCosmicRays )
	Return outputWave
end

Function detectCurvature(inputWave)
	Wave inputWave
	Variable p1 = 0
	Variable/G detectedCurvature
	NVAR detectedCurvature = detectedCurvature
	Make/FREE/O/N=(dimsize(inputWave,1)) maximumWave
	For(p1 = 0; p1 < dimsize(inputWave,1); p1+=1)
		Make/FREE/O/N=(dimsize(inputWave,0)) tempWave 
		tempWave[] = inputWave[p][p1]
		maximumWave[p1] =  waveMaxLoc(tempWave)
	endfor
	Loess/R=1/SMTH=.9 srcWave=maximumWave
	WaveStats/Q maximumWave
	If(V_numNans <= (dimsize(maximumWave,0)-3))
		CurveFit/Q poly 3, maximumWave/D
		detectedCurvature = k1/dimsize(inputWave,1)
	else
		detectedCurvature = 0
	endif
//	KillWaves/Z fit__free_,W_coef,W_sigma
//	If(abs(detectedCurvature) <= .0006)
//		detectedCurvature = 0
//	endIf
	Return detectedCurvature
end

Static Function waveMaxLoc(inputWave)
	Wave inputWave
	Duplicate/FREE/O inputwave,tempLocWave
	Variable p1 = 0
//	Loess/R=1/SMTH=.002 srcWave= tempLocWave
	Loess/R=1 srcWave= tempLocWave
//	For(p1 = 0; p1 < 65; p1 += 1)
//		Smooth/F 45, tempLocWave
//	endFor
	Variable maximum = WaveMax(tempLocWave)
	For(p1 = 0; p1 < numpnts(tempLocWave); p1+=1)
		If(tempLocWave[p1] == maximum)
			return pnt2x(tempLocWave,p1)
		endif
	endfor
end

Function img_curve_corr(inputWave, W_coef) //curve)
	Wave inputWave,W_coef
//	Variable curve //in px per px
	String inputWaveStr = NameOfWave(inputWave)

	Make/O/N=(dimsize(inputWave,0),dimsize(inputWave,1)) $("curvCorr")
	Wave outputWave = $("curvCorr") //, W_coef
	Variable p1 = 0 //,p2 = 0
	For(p1 = 0; p1 < dimsize(inputWave,1); p1 += 1)
		Duplicate/O/FREE/R=[][p1] inputWave,tempWave
//		outputWave[][p1] = (p+(curve*dimsize(inputWave,1)*q) < numpnts(tempWave) && (p+(curve*dimsize(inputWave,1)*q)) >= 0) ? tempWave[p+(curve*dimsize(inputWave,1)*q)] : tempWave[0]
		outputWave[][p1] = (p+((W_coef[1]+W_coef[2]*dimsize(inputWave,1))*q) < numpnts(tempWave) && (p+((W_coef[1]+W_coef[2]*dimsize(inputWave,1))*q)) >= 0) ? tempWave[p+((W_coef[1]+W_coef[2]*dimsize(inputWave,1))*q)] : tempWave[0]
	endFor
	Make/O/N=(dimsize(inputWave,0)) $("curvCorr1D")
	Wave outputWave1D = $("curvCorr1D") 
	MatrixOp/O outputWave1d = sumRows(outputWave)
	Redimension/N=(-1,0) outputWave1d
end

Function fancyCosmicRayDetection(inputMatrix, thresh)
	Wave inputMatrix
	Variable thresh
	Variable p1,p2, tempVariance,previousVariance
	MatrixOp/FREE/O inputMatrix_trans = inputMatrix^t
	inputMatrix_trans = abs(inputMatrix_trans)
	Make/D/O/N=(dimsize(inputMatrix_trans,0),dimsize(inputMatrix_trans,1)) averageMatrix,sortedMat, sortedPixelsMat
	
	For(p1 = 0; p1 < dimsize(inputMatrix_trans,1); p1 += 1)
		Duplicate/FREE/O/R=[][p1] inputMatrix_trans, tempWave
		Make/D/FREE/O/N=(numpnts(tempWave)) tempPixels = p
		Sort/R tempWave,tempWave,tempPixels
		sortedMat [][p1] = tempWave[p][0]
		sortedPixelsMat [][p1] = tempPixels[p]
		
		For(p2 = 0; p2 < dimsize(tempWave,0); p2 += 1)
			Duplicate/FREE/O/R=[p2,inf] tempWave,subTempWave
			WaveStats/Q subTempWave
		//	averageMatrix[p2][p1] = Variance(subTempWave)
			averageMatrix[p2][p1] = V_sdev^2
		endFor
		
		Duplicate/FREE/O tempWave,tempWaveRev
		tempWaveRev[] = tempWave[dimsize(tempWave,0)-(p+1)]
		
		Wave test = cumulativeWaveStats(tempWaveRev)
		averageMatrix[][p1] = test[dimSize(averageMatrix,0)-(p+1)][1]^2
		
	endFor
	
	
	Differentiate/DIM=0 averageMatrix/D=averageMatrix_DIF
	Differentiate/DIM=0 averageMatrix_DIF/D=averageMatrix_DIF_DIF
	Make/O/N=(dimsize(inputMatrix_trans,1)) peaks
	For(p1 = 0; p1 < dimsize(averageMatrix,1); p1 += 1)
		Duplicate/FREE/O/R=[][p1] averageMatrix_DIF_DIF,temp
		Duplicate/FREE/O/R=[][p1] sortedMat,temp2
		
		FindPeak/Q/B=(thresh)/I temp
		peaks[p1] = !numtype(V_peakLoc) ? abs(ceil(V_peakLoc)) : 0
		Variable tempSum = sum(temp2, peaks[p1], inf)
		if(peaks[p1] > 0)
			For(p2 = 0; p2 <= peaks[p1]; p2 += 1)
				sortedMat[p2][p1] = tempSum/(dimsize(inputMatrix_trans,1)-peaks[p1])
			endFor
		endIf
	endFor
	Duplicate/FREE/O sortedMat,unsortedMat
	For(p1 = 0; p1 < dimsize(sortedMat,1); p1 += 1)
		Duplicate/FREE/O/R=[][p1] unsortedMat,temp3
		Duplicate/FREE/O/R=[][p1] sortedPixelsMat,temp4
		Sort temp4,temp3,temp4
		unsortedMat[][p1] = temp3[p]
	endFor
	MatrixOp/FREE/O unsortedMat_trans = unsortedMat^t
	MatrixOp/FREE/O tempMatrix = inputMatrix_trans^t
	//Duplicate/O unsortedMat_trans, $(NameOfWave(inputMatrix) + "_clean")
	MatrixOp/O raw1D = sumRows(tempMatrix)
	raw1D /= dimsize(inputMatrix_trans,0)
	MatrixOp/O clean1D = sumRows(unsortedMat_trans)
	clean1D /= dimsize(inputMatrix_trans,0)
end

Function/WAVE cumulativeWaveStats(inputWave)
	Wave inputWave
	
	Make/FREE/O/N=(dimsize(inputWave,0),5) statsWave = 0
	Make/FREE/O/N=5 statsWaveTemp = {0,0,0,0,0}
	Variable p1
	For(p1=0;p1<dimsize(inputWave,0);p1+=1)
		Wave temp = onlineMoments(inputWave[p1],statsWaveTemp)
		statsWave[p1][] = temp[q]
		statsWaveTemp[] = statsWave[p1][p]
	endFor
	Return statsWave
end

Function/WAVE onlineMoments(newValue, oldSeriesDetails)
	Variable newValue
	Wave oldSeriesDetails
	Variable oldSeriesSize = oldSeriesDetails[0]
	Variable oldSeriesMean = oldSeriesDetails[1]
	Variable oldSeriesSigma = oldSeriesDetails[2]
	Variable oldSeriesSkew = oldSeriesDetails[3]
	Variable oldSeriesKurt = oldSeriesDetails[4]
	
	Variable oldSeriesM2
	Variable oldSeriesM3
	Variable oldSeriesM4
	
	If(oldSeriesSize <= 1 )
		oldSeriesM2 = 0
		oldSeriesM3 = 0
		oldSeriesM4 = 0
	else
		oldSeriesM2 = oldSeriesSigma^2*(oldSeriesSize-1)
		oldSeriesM3 = oldSeriesSkew*oldSeriesM2^(3/2)/oldSeriesSize^(1/2)
		oldSeriesM4 = (oldSeriesKurt+3)*oldSeriesM2^2/oldSeriesSize
	endIf
	
	Make/FREE/O/N=5 detailsOut
	Variable delta = newValue - oldSeriesMean
	Variable m1 = oldSeriesMean + delta/(oldSeriesSize+1)
	Variable m2 = oldSeriesM2+delta^2*oldSeriesSize/(oldSeriesSize+1)
	Variable m3 = oldSeriesM3+(delta^3*oldSeriesSize*(oldSeriesSize-1))/(oldSeriesSize+1)^2-(3*delta*(oldSeriesM2))/(oldSeriesSize+1)
	Variable m4 = oldSeriesM4+(delta^4*oldSeriesSize*((oldSeriesSize+1)^2-3*(oldSeriesSize+1)+3))/(oldSeriesSize+1)^3+(6*delta^2*oldSeriesM2)/(oldSeriesSize+1)^2-(4*delta*(oldSeriesM3))/(oldSeriesSize+1)
	
	Variable meanOut = m1
	Variable SigmaOut
	Variable SkewOut 
	Variable KurtOut
	
	If(oldSeriesSize == 0)
		SigmaOut = 0
	else
		SigmaOut = sqrt(m2/(oldSeriesSize))
	endIf
	
	If(m2 == 0)
		SkewOut = 0
		KurtOut = 0
	else
		SkewOut = m3*sqrt(oldSeriesSize+1)/m2^(3/2)
		KurtOut = m4*(oldSeriesSize+1)/m2^2-3
	endIf
	
	detailsOut = {oldSeriesSize+1,meanOut,SigmaOut,SkewOut,KurtOut}
	Return detailsOut
end
