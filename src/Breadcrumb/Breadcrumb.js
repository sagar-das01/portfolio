
import '../App.css';
import { Link } from 'react-router-dom';

function Breadcrumb(){
    return (
        <div className='bc-container'>
            <div className="bc">
                <Link className="link" to="/home">Home</Link>
                <Link className="link" to="/contacts">Contacts</Link>
                <Link className="link" to="/projects">Projects</Link>
                <Link className="link" to="/research">Research</Link>
                <Link className="link" to="/courses">Courses</Link>
            </div>
        </div>
    );
}

export default Breadcrumb;