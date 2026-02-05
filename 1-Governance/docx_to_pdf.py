#!/usr/bin/env python3
"""
Convert Word documents (.docx) to PDF using LibreOffice in headless mode.
Works on Linux environments including dev containers.
"""

import subprocess
import sys
import os
from pathlib import Path


def check_libreoffice():
    """Check if LibreOffice is installed."""
    try:
        result = subprocess.run(
            ['libreoffice', '--version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def install_libreoffice():
    """Install LibreOffice using apt."""
    print("LibreOffice not found. Installing...")
    try:
        subprocess.run(
            ['sudo', 'apt-get', 'update'],
            check=True
        )
        subprocess.run(
            ['sudo', 'apt-get', 'install', '-y', 'libreoffice', '--no-install-recommends'],
            check=True
        )
        print("LibreOffice installed successfully!")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error installing LibreOffice: {e}")
        return False


def convert_docx_to_pdf(docx_path, output_dir=None):
    """
    Convert a Word document to PDF.
    
    Args:
        docx_path: Path to the .docx file
        output_dir: Directory for output PDF (default: same as input file)
    
    Returns:
        Path to the generated PDF file, or None if conversion failed
    """
    docx_path = Path(docx_path)
    
    if not docx_path.exists():
        print(f"Error: File not found: {docx_path}")
        return None
    
    if docx_path.suffix.lower() not in ['.docx', '.doc']:
        print(f"Error: File must be a Word document (.doc or .docx)")
        return None
    
    # Use same directory as input if no output directory specified
    if output_dir is None:
        output_dir = docx_path.parent
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Converting: {docx_path.name}")
    print(f"Output directory: {output_dir}")
    
    try:
        # Run LibreOffice in headless mode to convert to PDF
        cmd = [
            'libreoffice',
            '--headless',
            '--convert-to', 'pdf',
            '--outdir', str(output_dir),
            str(docx_path)
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            print(f"Error during conversion:")
            print(result.stderr)
            return None
        
        # Calculate expected PDF filename
        pdf_path = output_dir / f"{docx_path.stem}.pdf"
        
        if pdf_path.exists():
            print(f"✓ Successfully converted to: {pdf_path}")
            return pdf_path
        else:
            print("Error: PDF file was not created")
            return None
            
    except subprocess.TimeoutExpired:
        print("Error: Conversion timed out")
        return None
    except Exception as e:
        print(f"Error during conversion: {e}")
        return None


def main():
    """Main function to handle command-line usage."""
    if len(sys.argv) < 2:
        print("Usage: python docx_to_pdf.py <input.docx> [output_directory]")
        print("\nExample:")
        print("  python docx_to_pdf.py document.docx")
        print("  python docx_to_pdf.py document.docx ./output")
        sys.exit(1)
    
    # Check if LibreOffice is installed
    if not check_libreoffice():
        print("LibreOffice is required for conversion.")
        response = input("Would you like to install it now? (y/n): ").lower()
        if response == 'y':
            if not install_libreoffice():
                print("Failed to install LibreOffice. Exiting.")
                sys.exit(1)
        else:
            print("Cannot proceed without LibreOffice. Exiting.")
            sys.exit(1)
    
    input_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else None
    
    pdf_path = convert_docx_to_pdf(input_file, output_dir)
    
    if pdf_path:
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
